#!/bin/sh
git_remote=$(git config --get remote.origin.url)
start=$(pwd)
extra_workflows=$(cd ../workflows; pwd)
for origin in $origins; do
  export origin
  git remote add upstream https://github.com/$origin/check-spelling.git --no-tags
  date=$(date +%s)
  for branch in $branches; do
    export branch
    export local=$origin/$branch/$date
    git fetch upstream $branch:$local
    git push origin $local -f

    pushd $(mktemp -d)
    git init .
    mkdir -p .github/workflows
    cd .github/workflows
    rsync $extra_workflows/* .
    perl -pi -e 's!uses: check-spelling/check-spelling.*!uses: $ENV{origin}/check-spelling\@$ENV{branch}!;' *
    git add .
    git commit -m 'Test workflows'
    git push "$start" HEAD:consumers -f
    popd
    git push origin consumers:"$local-consumers" -f
  done
  git remote rm upstream
done