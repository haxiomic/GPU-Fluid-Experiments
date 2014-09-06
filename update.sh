git reset --hard HEAD
git checkout master
aether build html5
git checkout gh-pages
cp -R Export/html5/bin/ html5