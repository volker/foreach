foreach - Parallel command execution (in specific sub directories)
==
Introduction
--
foreach is an erlang escript that allows for parallel command execution in
specified sub directories.

Build
--

	bash$ gmake escript

Configuration
--
Create a *.foreach* configuration file and place it into the parent folder.

	bash$ ls -l
	.	..	.foreach	first	second	third	fourth
	bash$ cat .foreach
	%% .foreach configuration file
	{
		{ default, "master" },
		[
			{ "1.x", [
				"first",
				"second",
				"third"
			]},
			{ "master", [
				"first",
				"second",
				"third",
				"fourth"
			]}
		]
	}

Usage
--
To execute the command "echo Hello World" in all four sub folders, execute

	bash$ foreach echo Hello World

To leverage a different folder set (e. g. '1.x' instead of master), use the *-s* command line switch. To change the number of worker processes, use the *-n* command line switch.

	bash$ foreach -s 1.x -n 2 git tag -a -m 'Release 1.0.0' 1.0.0
