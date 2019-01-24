svn export -q --force https://github.com/bmx-ng/bmx-ng.git/trunk $1

cd $1

mkdir bin
mkdir lib
mkdir mod

cd src
svn export -q --force https://github.com/bmx-ng/bcc.git/trunk bcc
svn export -q --force https://github.com/bmx-ng/bmk.git/trunk bmk
svn export -q --force https://github.com/bmx-ng/maxide.git/trunk maxide
cd ..

cd mod
svn export -q --force https://github.com/bmx-ng/brl.mod.git/trunk brl.mod
svn export -q --force https://github.com/bmx-ng/pub.mod.git/trunk pub.mod
svn export -q --force https://github.com/bmx-ng/maxgui.mod.git/trunk maxgui.mod

svn export -q --force https://github.com/bmx-ng/sdl.mod.git/trunk sdl.mod
svn export -q --force https://github.com/bmx-ng/mky.mod.git/trunk mky.mod
cd ..

cd src/bmk
cp -Rp resources ../../
cp core.bmk ../../bin
cp make.bmk ../../bin
cp custom.bmk ../../bin
cd ../..
