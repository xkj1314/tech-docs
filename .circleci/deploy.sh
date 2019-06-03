#!/usr/bin/env bash

# エラー時、実行を止める
set -e

# DEPLOY_DIR=deploy

# gitの諸々の設定
git config --global user.email $(git --no-pager show -s --format='%ae' HEAD)
git config --global user.name $CIRCLE_USERNAME

# gh-pagesブランチをdeployディレクトリにクローン
git checkout gh-pages
git clone -q --branch=gh-pages $CIRCLE_REPOSITORY_URL # $DEPLOY_DIR

# rsyncでhugoで生成したHTMLをコピー
# cd $DEPLOY_DIR
# rsync -arv --delete ../public/* .
rsync -arv --delete ./docs/* .

git add -f .
git commit -m "Deploy #$CIRCLE_BUILD_NUM from CircleCI [ci skip]" || true
git push origin gh-pages
