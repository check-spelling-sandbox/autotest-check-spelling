#!/usr/bin/env bash
git_remote=$(git config --get remote.origin.url)
extra_workflows=$(cd ../workflows; pwd)
git fetch origin autodetect-expired-artifact-2:autodetect-expired-artifact
for origin in $origins; do
  export origin
  git remote add upstream https://github.com/$origin/check-spelling.git --no-tags
  date=$(date +%s)
  for branch in $branches; do
    export branch
    export local=$origin/$branch/$date
    git fetch upstream $branch:$local
    if [ "$branch" = main ]; then
      git checkout $local
      if git cherry-pick autodetect-expired-artifact; then
        git commit --amend -m "$(
          echo 'cherry-pick fix for expired artifacts'
          echo
          echo https://github.com/check-spelling/check-spelling/commit/$(git rev-parse autodetect-expired-artifact)
        )"
        echo "::notice title=Backported autodetect-expired-artifact::To $local"
      else
        git cherry-pick --abort
        git clean -x
      fi
    fi
    git push origin $local -f

    pushd $(mktemp -d)
    git init .
    mkdir -p .github/workflows
    cd .github/workflows
    rsync $extra_workflows/* .
    perl -pi -e 's!uses: check-spelling/check-spelling.*!uses: $ENV{origin}/check-spelling\@$ENV{branch}!;' *
    git add .
    git commit -m 'Test workflows'
    git push "$GITHUB_WORKSPACE" HEAD:consumers -f
    popd
    git push origin consumers:"$local-consumers" -f
  done
  git remote rm upstream
done