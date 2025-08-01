
# @check-spelling-bot Report

## :red_circle: Please review
### See the [:scroll:action log](GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/actions/runs/GITHUB_RUN_ID) or :memo: job summary for details.

### Unrecognized words (6)

Aiglos
Alqua
diid
fixx
thiss
youu

<details><summary>These words are not needed and should be removed
</summary>invalid unexpectedlylong=
</details><p></p>

<details><summary>To accept these unrecognized words as correct, you could apply this commit</summary>


... in a clone of the [GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME](GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME) repository
([:information_source: how do I use this?](
https://docs.check-spelling.dev/Accepting-Suggestions)):
 =
```sh
git am <<'@@@@AM_MARKER'
From COMMIT_SHA Mon Sep 17 00:00:00 2001
From: check-spelling-bot <check-spelling-bot@users.noreply.github.com>
Date: COMMIT_DATE
Subject: [PATCH] [check-spelling] Update metadata

check-spelling run (push) for HEAD

Signed-off-by: check-spelling-bot <check-spelling-bot@users.noreply.github.com>
on-behalf-of: @check-spelling <check-spelling-bot@check-spelling.dev>
---
 t/unknown-words/config/expect/GITHUB_SHA.txt | 6 ++++++
 t/unknown-words/config/expect/other.txt                                    | 1 -
 2 files changed, 6 insertions(+), 1 deletion(-)

diff --git a/t/unknown-words/config/expect/GITHUB_SHA.txt b/t/unknown-words/config/expect/GITHUB_SHA.txt
new file mode 100644
index GIT_DIFF_NEW_FILE
--- /dev/null
+++ b/t/unknown-words/config/expect/GITHUB_SHA.txt
@@ -0,0 +1,6 @@
+Aiglos
+Alqua
+diid
+fixx
+thiss
+youu
diff --git a/t/unknown-words/config/expect/other.txt b/t/unknown-words/config/expect/other.txt
index GIT_DIFF_CHANGED_FILE
--- a/t/unknown-words/config/expect/other.txt
+++ b/t/unknown-words/config/expect/other.txt
@@ -1 +0,0 @@
-unexpectedlylong
--=
GIT_VERSION

@@@@AM_MARKER
```


And `git push` ...
</details>

**OR**


<details><summary>To accept these unrecognized words as correct and remove the previously acknowledged and now absent words,
you could run the following commands</summary>

... in a clone of the [GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME](GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME) repository
([:information_source: how do I use this?](
https://docs.check-spelling.dev/Accepting-Suggestions)):

``` sh
WORKSPACE/apply.pl 'GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/actions/runs/GITHUB_RUN_ID/attempts/' &&
git commit -m 'Update check-spelling metadata'
```
</details>

<details><summary>Available :books: dictionaries could cover words (expected and unrecognized) not in the :blue_book: dictionary</summary>

This includes both **expected items** (2) from WORKSPACE/t/unknown-words/config/expect/expect.txt
WORKSPACE/t/unknown-words/config/expect/other.txt and **unrecognized words** (6)

Dictionary | Entries | Covers | Uniquely
-|-|-|-
[extra:elvish.txt](EXTRA_DICTIONARIES_PROTO/elvish.txt)|6|2|2|

Consider creating a workflow (e.g. from GITHUB_SERVER_URL/check-spelling/spell-check-this/blob/main/.github/workflows/spelling.yml (`https://raw.githubusercontent.com/check-spelling/spell-check-this/main/.github/workflows/spelling.yml`)) and adding them:
``` yml
        with:
          extra_dictionaries: |
            extra:elvish.txt
```

To stop checking additional dictionaries, add:
``` yml
check_extra_dictionaries: ""
```

</details>
<details><summary>Forbidden patterns :no_good: (1)</summary>

In order to address this, you could change the content to not match the forbidden patterns (comments before forbidden patterns may help explain why they're forbidden), add patterns for acceptable instances, or adjust the forbidden patterns themselves.

These forbidden patterns matched content:

#### Should be `sample-file.txt`
```
\bsample\.file\b
```

</details>

<details><summary>Errors, Warnings, and Notices :x: (4)</summary>

#### See the [:scroll:action log](GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/actions/runs/GITHUB_RUN_ID) or :memo: job summary for details.

[:x: Errors, Warnings, and Notices](https://docs.check-spelling.dev/Event-descriptions) | Count
-|-
[:x: forbidden-pattern](https://docs.check-spelling.dev/Event-descriptions#forbidden-pattern) | 2
[:warning: ignored-expect-variant](https://docs.check-spelling.dev/Event-descriptions#ignored-expect-variant) | 1
[:warning: non-alpha-in-dictionary](https://docs.check-spelling.dev/Event-descriptions#non-alpha-in-dictionary) | 1
[:information_source: unused-config-file](https://docs.check-spelling.dev/Event-descriptions#unused-config-file) | 1

See [:x: Event descriptions](https://docs.check-spelling.dev/Event-descriptions) for more information.

</details>
<details><summary>Details :mag_right:</summary>

<details><summary>:open_file_folder: forbidden-pattern</summary>

note|path
-|-
`+` matches a line_forbidden.patterns entry: `(?![A-Z]\|[a-z]\|'\|\s\|=).`. | GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/blame/GITHUB_SHA/t/unknown-words/config/expect/expect.txt#L1
`sample.file` matches a line_forbidden.patterns entry: `\bsample\.file\b`. | unknown-words/input/sample.file:1
</details>

<details><summary>:open_file_folder: ignored-expect-variant</summary>

note|path
-|-
`Unexpectedlylong` is ignored by check-spelling because another more general variant is also in expect. | GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/blame/GITHUB_SHA/t/unknown-words/config/expect/expect.txt#L2
</details>

<details><summary>:open_file_folder: non-alpha-in-dictionary</summary>

note|path
-|-
Ignoring entry because it contains non-alpha characters. | GITHUB_SERVER_URL/GITHUB_REPOSITORY_OWNER/GITHUB_REPOSITORY_NAME/blame/GITHUB_SHA/t/unknown-words/config/expect/expect.txt#L1
</details>

<details><summary>:open_file_folder: unrecognized-spelling</summary>

note|path
-|-
`Aiglos` is not a recognized word. | unknown-words/input/sample.file:3
`Alqua` is not a recognized word. | unknown-words/input/sample.file:3
`diid` is not a recognized word. | unknown-words/input/sample.file:2
`fixx` is not a recognized word. | unknown-words/input/sample.file:2
`thiss` is not a recognized word. | unknown-words/input/sample.file:2
`youu` is not a recognized word. | unknown-words/input/sample.file:2
</details>

<details><summary>:open_file_folder: unused-config-file</summary>

note|path
-|-
config file not used | unknown-words/config/unsupported.file:1
</details>


</details>

