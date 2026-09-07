#!/bin/bash
set -e

cd dist/bootstrap/src/bcc
source bcc.console.release.macos.ARCH.build
cd ../../../..
mv dist/bootstrap/src/bcc/bcc bin

cd dist/bootstrap/src/bmk
source bmk.console.release.macos.ARCH.build
cd ../../../..
mv dist/bootstrap/src/bmk/bmk bin

bin/bmk makeapp -a -r mod/blitzmax.mod/locale.mod/tools/bmxlocale.bmx
mv mod/blitzmax.mod/locale.mod/tools/bmxlocale bin

bin/bmk makeapp -a -r src/bcc/lsp/bls.bmx
mv src/bcc/lsp/bls bin

bin/bmk makeapp -a -r src/docmods/docmods.bmx
mv src/docmods/docmods bin

bin/bmk makeapp -a -r src/makedocs/makedocs.bmx
mv src/makedocs/makedocs bin

bin/bmk makeapp -t gui -a -r src/maxide/maxide.bmx
mv src/maxide/maxide.app MaxIDE.app
