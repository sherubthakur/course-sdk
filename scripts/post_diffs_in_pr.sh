set -ue

marker_text="diffs_comment_marker"

function file_exists {
	local obj="$1"

	git cat-file -e "$obj" 2>/dev/null
}

function get_file {
	local obj="$1"

	file_exists "$obj" &&
		git --no-pager show "$obj"
}

function wrap_file {
	local obj="$1"

	file_exists "$obj" && {
		echo '```diff'
		get_file "$obj"
		echo '```'
		echo
	} || true
}

function print_both {
	local file="$1"
	local old="$2"
	local new="$3"

	echo file changed $file

	echo old content
	wrap_file "$old"

	echo "new content"
	wrap_file "$new"
}

function print_old {
	local file="$1"
	local old="$2"

	echo file removed $file

	wrap_file "$old"
}

function print_new {
	local file="$1"
	local new="$2"

	echo file created $file

	wrap_file "$new"
}

function comment_text {
	local base_ref="$1"
	local ref="$2"

	local files=( ` git diff --name-only "$base_ref" "$ref" solutions/*/*/diff/**.diff ` )

	for f in "${files[@]}"; do
		old="$base_ref:$f"
		new="$ref:$f"

		if file_exists "$old" && file_exists "$new"; then
			print_both "$f" "$old" "$new"
		elif file_exists "$old"; then
			print_old "$f" "$old"
		elif file_exists "$new"; then
			print_new "$f" "$new"
		else
			echo WTF; exit 1
		fi
	done

	echo
	echo "---"
	echo "_Posted by post_diffs_in_pr [codecrafters](https://github.com/codecrafters-io) Bot_"
	echo "_${marker_text}_"
}

function find_comment {
	curl -s "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${GITHUB_EVENT_NUMBER}/comments" |
		jq '[.[] | select(.user.type == "Bot" and (.body | contains("'"$marker_text"'")))][:1] | .[] | .id'
}

function comment_object {
	comment_text "$ARG_BASE_REF" "$ARG_REF" | jq -sR '{body: .}'
}

function create_comment {
	curl -sv \
		-X POST \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${GITHUB_EVENT_NUMBER}/comments" \
		-d @<(comment_object)
}

function update_comment {
	local comment_id="$1"

	curl -sv \
		-X PATCH \
		-H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/comments/$comment_id" \
		-d @<(comment_object)
}

function make_comment {
	comment_id=`find_comment`

	test -z "$comment_id" && create_comment || update_comment "$comment_id"
}

cd $REPO_PATH

#comment_object
#find_comment
make_comment
