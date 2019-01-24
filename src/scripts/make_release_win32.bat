cmd /c svn export https://github.com/bmx-ng/bmx-ng.git/trunk %1

cd %1

mkdir bin
mkdir lib
mkdir mod

cd src
cmd /c svn export https://github.com/bmx-ng/bcc.git/trunk bcc
cmd /c svn export https://github.com/bmx-ng/bmk.git/trunk bmk
cmd /c svn export https://github.com/bmx-ng/maxide.git/trunk maxide
cd ..

cd mod
cmd /c svn export https://github.com/bmx-ng/brl.mod.git/trunk brl.mod
cmd /c svn export https://github.com/bmx-ng/pub.mod.git/trunk pub.mod
cmd /c svn export https://github.com/bmx-ng/maxgui.mod.git/trunk maxgui.mod

cmd /c svn export https://github.com/bmx-ng/sdl.mod.git/trunk sdl.mod
cmd /c svn export https://github.com/bmx-ng/mky.mod.git/trunk mky.mod
cd ..
