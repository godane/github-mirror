#!/bin/sh

user="$1"
dir="$2"
tmp=/tmp/github-mirror

if [ ! "$user" -o ! -d "$dir" ]; then
	echo "Usage: $0 <user> <directory>"
	exit 1
fi

if [ ! -d "$dir" ]; then
	mkdir -p $dir
fi

cd $dir

repos="https://api.github.com/users/$user/repos"
watchers="https://api.github.com/repos/$user/watchers"

mkdir -p $tmp
curl -ks $repos > $tmp/repos

cat $tmp/repos | grep "git_url" | sed -re 's/.*(git:.*)".*/\1/' > $tmp/urls
cat $tmp/repos | grep description | sed -re 's/.*(: ".*)".*/\1/' | sed 's|: "||g' > $tmp/desc

#curl -ks $watchers > $tmp/watchers
pwd=$(pwd)
for url in $(cat $tmp/urls); do
	name="$(echo $url | cut -d/ -f5)"
	forks="https://api.github.com/repos/$user/${name/.git}/forks"
	if [ -d $name ]; then
		echo "Fetching $name ..."
		cd $name
		git fetch --all
		cd $pwd
	else
		echo "Cloning $name..."
		git clone --mirror $url $name
		cat $tmp/repos | grep -A1 $name | grep description | sed -re 's/.*(": .*)".*/\1/' | sed 's|": "||g' > $name/description
		echo "Cloning forks of $name"
		curl -ks $forks > $tmp/forks
		cat $tmp/forks | grep "git_url" | sed -re 's/.*(git:.*)".*/\1/' > $tmp/fork_urls
		for url in $(cat $tmp/fork_urls); do
			remote=$(echo $url | cut -d/ -f4)
			giturl=$(echo $url)
			cd $name
			echo "$remote $giturl"
			git remote add $remote $giturl $(echo $url | cut -d/ -f5)
			git fetch $remote
			cd $pwd
		done
	fi
done
