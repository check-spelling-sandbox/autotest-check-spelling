#!/usr/bin/env bash
git_remote=$(git config --get remote.origin.url)
extra_workflows=$(cd ../workflows; pwd)
cherry_pick_start=2
cherry_pick_stop=3
for cherry_pick in $(seq $cherry_pick_start $cherry_pick_stop); do
  git fetch origin autodetect-expired-artifact-$cherry_pick:autodetect-expired-artifact-$cherry_pick
done

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
      for cherry_pick in $(seq $cherry_pick_start $cherry_pick_stop); do
        fix=autodetect-expired-artifact-$cherry_pick
        if git cherry-pick $fix; then
          git commit --amend -m "$(
            echo "cherry-pick fix $cherry_pick for expired artifacts"
            echo
            echo https://github.com/check-spelling/check-spelling/commit/$(git rev-parse $fix)
          )"
          echo "::notice title=Backported $fix::To $local"
        else
          git cherry-pick --abort
          git clean -x
        fi
      done
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