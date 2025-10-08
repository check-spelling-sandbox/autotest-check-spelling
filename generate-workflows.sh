#!/usr/bin/env bash
mkdir -p ../workflows
extra_workflows=$(cd ../workflows; pwd)
for repo in $projects; do
  export repo
  repo_with_dashes=$(echo "$repo" | tr / -)
  gh repo clone "$repo" sandbox -- --single-branch --depth 1
  (
    cd sandbox
    for file in $(find .github/workflows \( -name '*.yml' -o -name '*.yaml' \) -print0 |
      xargs -0 grep -E -l --null 'uses:.*check-spelling/check-spelling' |
      xargs -0 grep -l 'checkout: true'); do
      workflow="$extra_workflows/$repo_with_dashes-$(basename "$file")"
      (
        echo "# $repo $(git rev-parse --abbrev-ref HEAD)=$(git rev-parse HEAD)"
        check_commit_messages="$(perl -ne 'next if /^\s*#/; next unless s/^\s*check_commit_messages:\s+//;print' "$file" | head -1)" \
        "$GITHUB_WORKSPACE/rewrite-workflow.pl" "$file"
      ) > "$workflow"
      diff -u "$file" "$workflow" || true
    done
  )
  rm -rf sandbox
done
