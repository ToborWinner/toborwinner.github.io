# This file is meant to be ran by Nix. The following variables are set by Nix (with the appropriate values)
# SOURCEDIR=./src
# OUTDIR=./
# TMPDIR=./tmp

set -e

mkdir -p "$OUTDIR/posts"
rm -rf "${OUTDIR:?}"/posts/* "$OUTDIR"/posts/.*

titles=()
descriptions=()
links=()
dates=()
formatteddates=()

declare -A dateindexes

for postdir in "$SOURCEDIR"/posts/*/; do
	echo "Building post '$postdir'."
	if [[ $postdir =~ ([A-Za-z0-9_\-]+)/$ ]]; then
		# Extract the post name to use in the URL from the path (name of dir)
		path_name="${BASH_REMATCH[1]}"
	else
		echo "Invalid post '$postdir': The name of the directory is invalid."
		exit 1
	fi

	meta_file="$postdir/meta.json"

	if [[ ! -f "$meta_file" ]]; then
		echo "Invalid post '$postdir': no meta.json file."
		exit 1
	fi

	# Extract values using jq
	title=$(jq -r '.title' "$meta_file")
	description=$(jq -r '.description' "$meta_file")
	date=$(jq -r '.date' "$meta_file")

	if [[ -z "$description" || -z "$date" || -z "$title" ]]; then
		echo "Invalid post '$postdir': The meta.json file must have title, author, description and date."
		exit 1
	fi

	if [[ -v dateindexes["$date"] ]]; then
		echo "Two posts have the same date! This is not allowed. Date: $(date -d @"$date" +"%Y-%m-%d %H:%M:%S")"
		exit 1
	fi

	dateindexes["$date"]="${#titles[@]}"

	link="/posts/$path_name"
	formatteddate="$(date -d @"$date" +"%Y-%m-%d")"

	titles+=("$title")
	descriptions+=("$description")
	links+=("$link")
	dates+=("$date")
	formatteddates+=("$formatteddate")

	source_file="$postdir/index.md"

	if [[ ! -f "$source_file" ]]; then
		echo "Invalid post '$postdir': no index.md file."
		exit 1
	fi

	mkdir "$OUTDIR/posts/$path_name"
	out_file="$OUTDIR/posts/$path_name/index.html"

	pandoc "$source_file" -o "$out_file" \
		-s -V lang=en --template "$SOURCEDIR/template.html" \
		-B "$SOURCEDIR/navbar.html" -A "$SOURCEDIR/footer.html" \
		--highlight-style "$SOURCEDIR/highlight.theme" -V style="$(cat "$SOURCEDIR/style.css")" \
		--from markdown -t html -M document-css=false \
		-M title="$title" -M description="$description" -M date="$formatteddate"
done

mapfile -t sorted_keys < <(printf "%s\n" "${!dateindexes[@]}" | sort -nr)

sorted_posts=()

for key in "${sorted_keys[@]}"; do
	sorted_posts+=("${dateindexes["$key"]}")
done

posts=""

for key in "${sorted_posts[@]}"; do
	link="${links[$key]}"
	title=$(echo "${titles["$key"]}" | sed -e 's/&/\\&/g' -e 's/~/\\~/g')
	description="${descriptions[$key]}"
	date="${formatteddates[$key]}"

	# shellcheck disable=SC2016
	posts+=$(sed \
		-e 's~\$link\$~'"$link"'~g' \
		-e 's~\$title\$~'"$title"'~g' \
		-e 's~\$date\$~'"$date"'~g' \
		-e 's~\$desc\$~'"$description"'~g' \
		"$SOURCEDIR/post.html")
done

recentposts=""

for key in "${sorted_posts[@]:0:4}"; do
	link="${links[$key]}"
	title=$(echo "${titles["$key"]}" | sed -e 's/&/\\&/g' -e 's/~/\\~/g')
	description="${descriptions[$key]}"
	date="${formatteddates[$key]}"

	# shellcheck disable=SC2016
	recentposts+=$(sed \
		-e 's~\$link\$~'"$link"'~g' \
		-e 's~\$title\$~'"$title"'~g' \
		-e 's~\$date\$~'"$date"'~g' \
		-e 's~\$desc\$~'"$description"'~g' \
		"$SOURCEDIR/post.html")
done

echo "Creating temporary directory in '$TMPDIR'"
mkdir -p "$TMPDIR"
echo -n "$posts" >"$TMPDIR/posts.html.tmp"
echo -n "$recentposts" >"$TMPDIR/recentposts.html.tmp"

# Guides

touch "$TMPDIR/guides.html.tmp"

jq -c '.[]' "$SOURCEDIR/posts/guides.json" | while read -r obj; do
	name=$(echo "$obj" | jq -r '.name')
	description=$(echo "$obj" | jq -r '.description')

	touch "$TMPDIR/guideposts.html.tmp"

	echo "$obj" | jq -r '.posts[]' | while read -r postobj; do
		index="${dateindexes["$postobj"]}"
		title=$(echo "${titles["$index"]}" | sed -e 's/&/\\&/g' -e 's/~/\\~/g')
		link="${links["$index"]}"

		echo "$title"

		# shellcheck disable=SC2016
		sed \
			-e 's~\$title\$~'"$title"'~g' \
			-e 's~\$link\$~'"$link"'~g' \
			"$SOURCEDIR/guidepost.html" >>"$TMPDIR/guideposts.html.tmp"
	done

	touch "$TMPDIR/todoguideposts.html.tmp"

	echo "$obj" | jq -r '.todo[]' | while read -r postobj; do
		# shellcheck disable=SC2016
		sed \
			-e 's~\$title\$~'"$postobj"'~g' \
			"$SOURCEDIR/todoguidepost.html" >>"$TMPDIR/todoguideposts.html.tmp"
	done

	# shellcheck disable=SC2016
	sed \
		-e 's~\$name\$~'"$name"'~g' \
		-e 's~\$desc\$~'"$description"'~g' \
		-e '/\$posts\$/{
			s/\$posts\$//g
			r '"$TMPDIR/guideposts.html.tmp"'
		}' \
		-e '/\$todoposts\$/{
			s/\$todoposts\$//g
			r '"$TMPDIR/todoguideposts.html.tmp"'
		}' \
		"$SOURCEDIR/guide.html" >>"$TMPDIR/guides.html.tmp"
done

mkdir -p "$OUTDIR/guides"

# shellcheck disable=SC2016
sed \
	-e '/\$navbar\$/{
		s/\$navbar\$//g
		r '"$SOURCEDIR/navbar.html"'
	}' \
	-e '/\$footer\$/{
		s/\$footer\$//g
		r '"$SOURCEDIR/footer.html"'
	}' \
	-e '/\$guides\$/{
		s/\$guides\$//g
		r '"$TMPDIR/guides.html.tmp"'
	}' \
	-e '/\$style\$/{
		s/\$style\$//g
		r '"$SOURCEDIR/style.css"'
	}' "$SOURCEDIR/guides.html" >"$OUTDIR/guides/index.html"

# shellcheck disable=SC2016
sed \
	-e '/\$navbar\$/{
		s/\$navbar\$//g
		r '"$SOURCEDIR/navbar.html"'
	}' \
	-e '/\$footer\$/{
		s/\$footer\$//g
		r '"$SOURCEDIR/footer.html"'
	}' \
	-e '/\$posts\$/{
		s/\$posts\$//g
		r '"$TMPDIR/recentposts.html.tmp"'
	}' \
	-e '/\$style\$/{
		s/\$style\$//g
		r '"$SOURCEDIR/style.css"'
	}' "$SOURCEDIR/index.html" >"$OUTDIR/index.html"

# shellcheck disable=SC2016
sed \
	-e '/\$navbar\$/{
		s/\$navbar\$//g
		r '"$SOURCEDIR/navbar.html"'
	}' \
	-e '/\$footer\$/{
		s/\$footer\$//g
		r '"$SOURCEDIR/footer.html"'
	}' \
	-e '/\$posts\$/{
		s/\$posts\$//g
		r '"$TMPDIR/posts.html.tmp"'
	}' \
	-e '/\$style\$/{
		s/\$style\$//g
		r '"$SOURCEDIR/style.css"'
	}' "$SOURCEDIR/posts.html" >"$OUTDIR/posts/index.html"

# This is only necessary when running the script without Nix
# echo "Removing temporary directory"
# rm -r "$TMPDIR"
