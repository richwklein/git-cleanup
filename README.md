# git-cleanup

Script for cleanup of local git working directories.

## Description

The `git_cleanup.sh` script is designed to help you clean up your local Git repositories. It performs the following tasks:

- Fetches updates from remote repositories and prunes any remote-tracking references that no longer exist on the remote.
- Removes local branches that have been deleted on the remote.
- Removes local branches that have been merged into the main branch.
- Prunes orphaned objects from the local repository.
- Checks for old stashes and notifies if any are found.
- Optionally removes any untracked branches.

## Usage

You can run the script with the following options:

```sh
Usage: ./git_cleanup.sh [-d directory] [-u]
```

* -d directory: Specify the directory to clean up. Defaults to the current directory (.).
* -u: Removes untracked branches.

### Behavior

If the specified directory contains a .git file, the script will clean up that repository.
If the specified directory does not contain a .git file, the script will recurse into child directories to find and clean up Git repositories.

### Examples

Using the current directory:

```sh
./git_cleanup.sh
```

Specifying a different directory (e.g., /path/to/dir)

```sh
./git_cleanup.sh -d /path/to/dir 
```

Cleaning untracked branches

```sh
./git_cleanup.sh -d /path/to/dir -u
```

## Creating a Command Line Alias

If all your GitHub repositories are stored in a single directory, it can be helpful to create a command line alias to run this script easily. Here is an example of how to define an alias in your `.zshrc` file:

```sh
alias cleanup="sh $PROJECTS/git-cleanup/git_cleanup.sh -d $PROJECTS"
```

In this example, `$PROJECTS` is an environment variable that you have set to the directory containing all your projects. This alias will run the [git_cleanup.sh](git_cleanup.sh) script from its checked-out location against the directory specified by `$PROJECTS`.

### Setting the Environment Variable

To set the `$PROJECTS` environment variable, add the following line to your .zshrc file (or .bashrc if you are using Bash):

```sh
export PROJECTS="/path/to/your/projects"
```

Replace "/path/to/your/projects" with the actual path to your projects directory. After adding this line, reload your shell configuration by running:

```sh
source ~/.zshrc
```

Now, you can use the cleanup alias to run the script against all your projects:

```sh
cleanup
```

This will execute the [git_cleanup.sh](./git_cleanup.sh) script on the directory specified by the `$PROJECTS` environment variable.

## Disclaimer

This script has been cleaned up and improved using Large Language Models (LLMs) to ensure better readability, maintainability, and functionality. Please review the code and test it in your environment before using it in production.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
