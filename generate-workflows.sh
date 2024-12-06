#!/bin/sh
mkdir -p ../workflows
extra_workflows=$(cd ../workflows; pwd)
for repo in $projects; do
  export repo
  repo_with_dashes=$(echo "$repo" | tr / -)
  gh repo clone $repo sandbox -- --single-branch --depth 1
  (
    cd sandbox
    for file in $(find .github/workflows \( -name '*.yml' -o -name '*.yaml' \) -print0 |
      xargs -0 grep -E -l --null 'uses:.*check-spelling/check-spelling' |
      xargs -0 grep -l 'checkout: true'); do
      workflow="$extra_workflows/$repo_with_dashes-$(basename $file)"
      ./rewrite-workflow.pl $file > "$workflow"
    done
  )
  rm -rf sandbox
done
