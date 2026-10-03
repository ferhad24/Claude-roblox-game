#!/usr/bin/env bash
# Bütün statik və məntiq yoxlamaları. Roblox Studio tələb etmir.
# Tələblər: rojo, stylua, lune, luau-lsp (+ Roblox tip tərifləri .tools/roblox.d.luau)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== 1. Format (StyLua) =="
stylua --check src tests tools

echo "== 2. Rojo yığımı =="
mkdir -p build
rojo build default.project.json -o build/TinyGrove.rbxl
rojo sourcemap default.project.json -o sourcemap.json

echo "== 3. Strict tip yoxlaması (luau-lsp + Roblox tipləri) =="
if [ -f .tools/roblox.d.luau ]; then
	out=$(luau-lsp analyze --definitions=.tools/roblox.d.luau --sourcemap=sourcemap.json --platform=roblox src 2>&1 | grep -E "^/" || true)
	if [ -n "$out" ]; then
		echo "$out"
		exit 1
	fi
	echo "tip xətası yoxdur"
else
	echo "XƏBƏRDARLIQ: .tools/roblox.d.luau yoxdur, tip yoxlaması atlandı (bax: docs/SETUP.md)"
fi

echo "== 4. Məntiq testləri (Lune) =="
lune run tests/run.luau

echo "== 5. DOM tüstü testləri (Lune Roblox DOM) =="
lune run tests/dom/world_smoke.luau
lune run tests/dom/ui_smoke.luau

echo "Bütün yoxlamalar keçdi."
