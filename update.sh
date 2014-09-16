git reset --hard HEAD
git checkout master
aether build html5
git checkout gh-pages
rm -rf ./html5
cp -R Export/html5/bin/ ./html5