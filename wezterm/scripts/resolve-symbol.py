#!/usr/bin/env python3
import argparse
import json
import os
import queue
import subprocess
import sys
import threading
from pathlib import Path
from urllib.parse import quote, unquote, urlparse


C_EXTENSIONS = {'.c', '.h'}
CPP_EXTENSIONS = {'.cc', '.cpp', '.cxx', '.c++', '.hh', '.hpp', '.hxx', '.h++'}
PYTHON_EXTENSIONS = {'.py', '.pyi'}


def path_to_uri(path):
    resolved = Path(path).resolve()
    return 'file:///' + quote(str(resolved).replace('\\', '/'), safe='/:')


def uri_to_path(uri):
    parsed = urlparse(uri)
    if parsed.scheme != 'file':
        raise RuntimeError(f'unsupported uri: {uri}')
    path = unquote(parsed.path)
    if os.name == 'nt' and path.startswith('/') and len(path) > 2 and path[2] == ':':
        path = path[1:]
    return str(Path(path))


def find_python(root):
    candidates = []
    env_python = os.environ.get('VIRTUAL_ENV')
    if env_python:
        candidates.append(Path(env_python) / 'Scripts' / 'python.exe')
        candidates.append(Path(env_python) / 'bin' / 'python')
    for name in ('.venv', 'venv', 'env'):
        candidates.append(Path(root) / name / 'Scripts' / 'python.exe')
        candidates.append(Path(root) / name / 'bin' / 'python')
    candidates.append(Path(sys.executable))
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return sys.executable


def read_lsp_message(stream):
    headers = {}
    while True:
        line = stream.readline()
        if not line:
            raise RuntimeError('language server closed stdout')
        line = line.decode('ascii', errors='replace').strip()
        if not line:
            break
        name, _, value = line.partition(':')
        headers[name.lower()] = value.strip()
    length = int(headers.get('content-length', '0'))
    if length <= 0:
        raise RuntimeError('language server sent an empty message')
    payload = stream.read(length)
    return json.loads(payload.decode('utf-8'))


def start_lsp_reader(process, messages):
    def run():
        try:
            while True:
                messages.put(read_lsp_message(process.stdout))
        except Exception as exc:
            messages.put({'_reader_error': str(exc)})

    thread = threading.Thread(target=run, daemon=True)
    thread.start()


def send_lsp(process, payload):
    body = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    header = f'Content-Length: {len(body)}\r\n\r\n'.encode('ascii')
    process.stdin.write(header + body)
    process.stdin.flush()


def wait_lsp_response(messages, request_id, timeout=15):
    while True:
        message = messages.get(timeout=timeout)
        if '_reader_error' in message:
            raise RuntimeError(message['_reader_error'])
        if message.get('id') == request_id:
            if 'error' in message:
                raise RuntimeError(json.dumps(message['error'], ensure_ascii=False))
            return message.get('result')


def first_location(result):
    if not result:
        return None
    if isinstance(result, list):
        return result[0] if result else None
    return result


def clangd_resolve(args):
    executable = 'clangd'
    try:
        process = subprocess.Popen(
            [executable],
            cwd=args.project_root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0,
        )
    except FileNotFoundError as exc:
        raise RuntimeError('clangd not found in PATH') from exc

    messages = queue.Queue()
    start_lsp_reader(process, messages)
    file_path = str(Path(args.file).resolve())
    file_uri = path_to_uri(file_path)
    language_id = 'c' if Path(file_path).suffix.lower() in C_EXTENSIONS else 'cpp'
    root_uri = path_to_uri(args.project_root)
    text = Path(file_path).read_text(encoding='utf-8', errors='replace')

    try:
        send_lsp(process, {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
                'processId': os.getpid(),
                'rootUri': root_uri,
                'capabilities': {},
            },
        })
        wait_lsp_response(messages, 1)
        send_lsp(process, {'jsonrpc': '2.0', 'method': 'initialized', 'params': {}})
        send_lsp(process, {
            'jsonrpc': '2.0',
            'method': 'textDocument/didOpen',
            'params': {
                'textDocument': {
                    'uri': file_uri,
                    'languageId': language_id,
                    'version': 1,
                    'text': text,
                },
            },
        })

        methods = ['textDocument/definition']
        if args.target.lower() == 'declaration':
            methods = ['textDocument/declaration', 'textDocument/definition']
        elif args.target.lower() == 'any':
            methods = ['textDocument/definition', 'textDocument/declaration']

        request_id = 2
        for method in methods:
            send_lsp(process, {
                'jsonrpc': '2.0',
                'id': request_id,
                'method': method,
                'params': {
                    'textDocument': {'uri': file_uri},
                    'position': {
                        'line': max(args.line - 1, 0),
                        'character': max(args.column - 1, 0),
                    },
                },
            })
            result = first_location(wait_lsp_response(messages, request_id))
            request_id += 1
            if result:
                range_info = result.get('targetRange') or result.get('range') or {}
                start = range_info.get('start') or {}
                return {
                    'path': uri_to_path(result.get('targetUri') or result.get('uri')),
                    'line': int(start.get('line', 0)) + 1,
                    'column': int(start.get('character', 0)) + 1,
                    'provider': 'clangd',
                }
        return None
    finally:
        try:
            send_lsp(process, {'jsonrpc': '2.0', 'id': 99, 'method': 'shutdown', 'params': None})
            send_lsp(process, {'jsonrpc': '2.0', 'method': 'exit', 'params': {}})
        except Exception:
            pass
        process.terminate()


def python_resolve(args):
    try:
        import jedi
    except ImportError as exc:
        raise RuntimeError('Python semantic navigation requires jedi in the active interpreter') from exc

    file_path = str(Path(args.file).resolve())
    code = Path(file_path).read_text(encoding='utf-8', errors='replace')
    environment = None
    python_executable = find_python(args.project_root)
    try:
        environment = jedi.create_environment(python_executable, safe=False)
    except Exception:
        environment = None

    project = jedi.Project(path=args.project_root)
    script = jedi.Script(code=code, path=file_path, project=project, environment=environment)
    definitions = script.goto(
        line=args.line,
        column=max(args.column - 1, 0),
        follow_imports=True,
        follow_builtin_imports=True,
    )
    if not definitions:
        return None

    item = definitions[0]
    if not item.module_path or not item.line:
        return None
    return {
        'path': str(item.module_path),
        'line': int(item.line),
        'column': int(item.column or 0) + 1,
        'provider': 'python-jedi',
    }


def resolve(args):
    extension = Path(args.file).suffix.lower()
    if extension in C_EXTENSIONS or extension in CPP_EXTENSIONS:
        return clangd_resolve(args)
    if extension in PYTHON_EXTENSIONS:
        return python_resolve(args)
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project-root', required=True)
    parser.add_argument('--file', required=True)
    parser.add_argument('--line', type=int, required=True)
    parser.add_argument('--column', type=int, required=True)
    parser.add_argument('--symbol', default='')
    parser.add_argument('--target', default='Definition')
    args = parser.parse_args()

    result = resolve(args)
    if not result:
        raise RuntimeError(f'no semantic {args.target.lower()} found for {args.symbol}')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)