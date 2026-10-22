#!/usr/bin/env python3
"""
adb_relay.py — ADB 无线调试的本地 TCP 隧道（TUN 代理环境专用）

问题背景：
  如果电脑开着 TUN 模式代理（Clash / Mihomo / Surge 等），代理会接管
  所有对外 TCP 连接，导致 `adb pair` / `adb connect` 报错：
      error: protocol fault (couldn't read status message)
  现象是连接"假成功"但数据永远到不了手机。

解决思路：
  ADB 本身不支持代理，但 TCP 隧道可以。本脚本在本地开一个端口，
  把收到的连接通过本机混合代理（HTTP CONNECT）转发到手机：

      adb  --TCP-->  127.0.0.1:本地端口  --HTTP CONNECT-->  本机代理  --TCP-->  手机

用法：
  python3 adb_relay.py <本地监听端口> <手机IP:手机端口> [代理地址]

示例：
  python3 adb_relay.py 15556 192.168.1.222:39069
  adb connect 127.0.0.1:15556

注意：
  - 默认代理为 127.0.0.1:7890（Clash 混合端口），可用第三个参数改
  - 无线调试每次开关端口都会变，连接失败时去手机上核对新端口
  - 保持本脚本运行，Ctrl+C 或 kill 结束隧道
"""
import socket
import sys
import threading

LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 15555
TARGET = sys.argv[2] if len(sys.argv) > 2 else ""
PROXY = (
    int(sys.argv[4]) if len(sys.argv) > 4 else 7890,
    sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1",
)
# 允许 "host port" 形式书写代理
if len(sys.argv) > 3 and ":" in sys.argv[3]:
    host, port = sys.argv[3].rsplit(":", 1)
    PROXY = (int(port), host)


def pipe(a: socket.socket, b: socket.socket) -> None:
    """双向搬运数据，任何一端断开就关闭两端。"""
    try:
        while True:
            data = a.recv(65536)
            if not data:
                break
            b.sendall(data)
    except OSError:
        pass
    finally:
        for s in (a, b):
            try:
                s.close()
            except OSError:
                pass


def handle(client: socket.socket) -> None:
    proxy_sock = socket.create_connection(PROXY, timeout=10)
    host, port = TARGET.rsplit(":", 1)
    req = f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}:{port}\r\n\r\n"
    proxy_sock.sendall(req.encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        chunk = proxy_sock.recv(4096)
        if not chunk:
            raise RuntimeError("proxy closed during CONNECT")
        resp += chunk
    status = resp.split(b"\r\n", 1)[0].decode(errors="replace")
    if " 200" not in status:
        raise RuntimeError(f"CONNECT failed: {status}")
    threading.Thread(target=pipe, args=(client, proxy_sock), daemon=True).start()
    threading.Thread(target=pipe, args=(proxy_sock, client), daemon=True).start()


def main() -> None:
    if not TARGET:
        print(__doc__)
        sys.exit(1)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", LISTEN_PORT))
    srv.listen(5)
    print(f"relay listening on 127.0.0.1:{LISTEN_PORT} -> {TARGET} via {PROXY}", flush=True)
    while True:
        client, _ = srv.accept()
        try:
            handle(client)
        except Exception as e:  # noqa: BLE001
            print(f"relay error: {e}", flush=True)
            client.close()


if __name__ == "__main__":
    main()
