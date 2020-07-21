#! /bin/true
#
# some shortcuts for Git actions
#
# only functions are defined here, no further actions, include it to your .profile/.bashrc
#
# required Git settings:
#
# repo origin - parent
# repo github - corresponding repo on GitHub, if any
# repo upstream - upstream repo, if any
#
# environment GPGKEY - ID of key to use for commit signing, without a key all 'git push' commands are skipped
# environment GITHOME - base directory of all Git repos, if $(pwd) isn't within, no actions are taken by functions
#
# branches, which have to be merged with preference for our local changes
#
__yf_force_ours_branches="description"

__yf_git_in_githome_directory()
{
	[ -z "$GITHOME" ] && return 1
	pwd="$(pwd)"
	[ "${pwd#$GITHOME}" = "$pwd" ] && return 1
	return 0
}

__yf_is_force_ours_branch()
{
	for b in $__yf_force_ours_branches; do
		[ "$1" = "$b" ] && return 0
	done
	return 1
}


__yf_git_rebase_branch()
{
	__yf_git_in_githome_directory || return 1
	[ -z "$1" ] && return 1
	# only branches with differences to 'master' have to get updated
	[ "$(command git rev-list --count "$1" ^master 2>/dev/null)" = "0" ] && return
	command git checkout $1
	command git rebase master
	[ -z "$GPGKEY" ] && return
	# origin has to exist, but let's make sure
	[ -z "$(command git remote | grep -- "^origin")" ] && return 1
	command git push --force origin
	[ -n "$(command git remote | grep -- "^github")" ] && command git push --force github
}

__yf_git_count_branch()
{
	__yf_git_in_githome_directory || return 1
	[ "$1" = "master" ] && return 0
	[ "$1" = "." ] && branch="" || branch="$1"
	ahead=$(command git log --oneline master..${branch} 2>/dev/null | wc -l | sed -n -e "s|^\([0-9]*\).*|\1|p")
	behind=$(command git log --oneline ${branch}..master 2>/dev/null | wc -l | sed -n -e "s|^\([0-9]*\).*|\1|p")
	if [ $(( ahead + behind )) -eq 0 ]; then
		printf "Branch '%s' is even with master.\n" "$1" 1>&2
	elif [ $(( ahead )) -gt 0 ] && [ $(( behind )) -gt 0 ]; then
		printf "Branch '%s' is %u commits ahead of and %u commits behind master.\n" "$1" "$ahead" "$behind" 1>&2 
	elif [ $(( ahead )) -gt 0 ]; then
		printf "Branch '%s' is %u commits ahead of master.\n" "$1" "$ahead" 1>&2 
	else
		printf "Branch '%s' is %u commits behind master.\n" "$1" "$behind" 1>&2 
	fi
}

__yf_git_show_branch()
{
	__yf_git_in_githome_directory || return 1
	[ "$1" = "master" ] && return 0
	[ "$1" = "." ] && branch="" || branch="$1"
	printf "### Branch '%s' ###\n" "$1" 1>&2 
	printf ">>> ahead >>>\n" 1>&2
	command git log --oneline master..${branch} 2>/dev/null | cat
	printf "<<< behind <<<\n" 1>&2
	command git log --oneline ${branch}..master 2>/dev/null | cat
	printf "### Finished '%s' ###\n" "$1" 1>&2 
}

__yf_git_iterate_branches()
{
	__yf_git_in_githome_directory || return 1
	[ -z "$1" ] && return 1
	if [ "$(pwd)" = "$GITHOME/YourFreetz"  ]; then 
		# only handle a limited count of branches
		# YourFritz, master and every branch starting with an underscore (means private) are ignored
		for branch in $(command git branch -l | sed -e "s/^* /  /" | sed -e "s/^  //" | grep -v "master\$" | grep -v YourFritz | grep -v "^_.*"); do
			__yf_git_$1_branch $branch
		done
	else
		for branch in $(command git branch -l | sed -e "s/^* /  /" | sed -e "s/^  //" | grep -v "^_.*"); do
			__yf_git_$1_branch $branch
		done
	fi
}

__yf_git_iterate_branches_with_private()
{
	__yf_git_in_githome_directory || return 1
	[ -z "$1" ] && return 1
	for branch in $(command git branch -l | sed -e "s/^* /  /" | sed -e "s/^  //"); do
		__yf_git_$1_branch $branch
	done
}

__yf_git_state_repos()
{
	[ -z "$GITHOME" ] && return 1
	cwd="$(pwd)"
	trap 'cd $cwd' INT
	cd "$GITHOME"
	for d in $(find . -type d); do 
		[ -d "$d/.git" ] || continue; 
		cd "$d"
		printf "\n\033[1m%s\033[0m\n\n" "$d"
		__yf_git_iterate_branches count
		cd ..
	done
	cd "$cwd"
}

__yf_git_update_yourfreetz_repo()
{
	command git checkout master
	command git pull upstream master && command git push origin || return 1
	[ -n "$(command git remote | grep -- "^github")" ] && command git push --force github
}

__yf_git_merge_to_yourfritz_branch()
{			
			command git tag -d last_update
			command git tag last_update $1
			command git checkout YourFritz || return 1
			command git reset --hard last_update
			unset branches
			for branch in $(git branch -l | sed -e "s/^* /  /" | sed -e "s/^  //"); do
				if [ "$(expr \( "$branch" : "\(_\).*" \) )" = "_" ]; then
					printf "local-only branch '%s' skipped while merging" "$branch" 1>&2
					continue
				elif [ "$branch" = "YourFritz" ] || [ "$branch" = "master" ]; then
					continue
				elif __yf_is_force_ours_branch "$branch"; then
					continue
				fi
				branches="${branches}${branches:+ }${branch}"
			done
			[ -z "$branches" ] && return 1
			command git merge --no-edit --log=10 $branches
			for branch in $__yf_force_ours_branches; do
				command git merge --no-edit --strategy recursive --strategy-option=ours --log=10 $branch
			done
			command git push -f origin
			[ -n "$(git remote | grep -- "^github")" ] && command git push --force github
}

git()
{
	! command -v git 2>/dev/null 1>&2 && printf "Missing '%s' command.\a\n" "git" 1>&2 && return 1
	
	case "$1" in
		("reb")
			__yf_git_rebase_branch "$@"
			;;
		
		("cnt")
			[ -z "$2" ] && __yf_git_iterate_branches_with_private count || __yf_git_count_branch "$2"
			;;

		("vw")
			[ -z "$2" ] && __yf_git_iterate_branches_with_private show || __yf_git_show_branch "$2"
			;;

		("repos"|"allstat")
			__yf_git_state_repos
			;;

		("yourfreetz")
			[ -z "$GITHOME" ] && return 1
			[ -z "$GPGKEY" ] && return 1
			cwd="$(pwd)"
			cd "$GITHOME/YourFreetz"
			command git remote update
			[ "$(git rev-list --count ^origin/master upstream/master)" = "0" ] && cd "$cwd" && printf "Nothing to update.\a\n" && return 0
			last_commit=$(git rev-parse origin/master 2>/dev/null)
			__yf_git_update_yourfreetz_repo || return 1
			__yf_git_iterate_branches rebase
			__yf_git_merge_to_yourfritz_branch "$last_comit"
			;;
			
		(*)
			command -v git 2>/dev/null 1>&2 || return 1
			command git "$@"
			;;
	esac
}
