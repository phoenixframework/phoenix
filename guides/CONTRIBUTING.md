### Contributing to the Phoenix Guides

Please take a moment to review this document in order to make the contribution
process easy and effective for everyone involved!

#### General Principles

These Guides aim to be inclusive. We use "we" and "our" instead of "you" and
"your" to foster this sense of inclusion.

Ideally there is something for everybody in each guide, from beginner to expert.
This is hard, maybe impossible. When we need to compromise, we do so on behalf
of beginning users because expert users have more tools at their disposal to
help themselves.

The general pattern we use for presenting information is to first introduce a
small, discreet topic, then write a small amount of code to demonstrate the
concept, then verify that the code worked.

In this way, we build from small, easily digestible concepts into more complex
ones. The shorter this cycle is, as long as the information is still clear and
complete, the better.


#### Formatting

- We use the "elixir" code fence for all module code.
- We use the "console" code fence for iex and shell commands.
- We use the "html" code fence for html templates, even if there is elixir code
  in the template.
- We use backticks for filenames and directory paths.
- We use backticks for module names, function names, and variable names.

#### Pull requests

Good pull requests - patches, improvements, new features - are a fantastic
help. They should remain focused in scope and avoid containing unrelated
commits.

**IMPORTANT**: By submitting a patch, you agree that your work will be
licensed under the license used by the project.

If you have any large pull request in mind (e.g. adding a new guide,
completely changing an existing one, etc), **please ask first** otherwise
you risk spending a lot of time working on something that the project's
developers might not want to merge into the project.

When working with git, we recommend the following process in order to
craft an excellent pull request:

1. [Fork](http://help.github.com/fork-a-repo/) the project, clone your fork,
and configure the remotes:

```bash
# Clone your fork of the repo into the current directory
git clone https://github.com/<your-username>/phoenix_guides
# Navigate to the newly cloned directory
cd phoenix_guides
# Assign the original repo to a remote called "upstream"
git remote add upstream https://github.com/phoenixframework/phoenix_guides
```

2. If you cloned a while ago, get the latest changes from upstream:

```bash
git checkout master
git pull upstream master
```

3. Create a new topic branch (off of `master`) to contain your feature, change,
or fix.

**IMPORTANT**: Making changes in `master` is discouraged. You should always
keep your local `master` in sync with upstream `master` and make your
changes in topic branches.

```bash
git checkout -b <topic-branch-name>
```

4. Commit your changes in logical chunks. Keep your commit messages organized,
with a short description in the first line and more detailed information on
the following lines. Feel free to use Git's
[interactive rebase](https://help.github.com/articles/interactive-rebase)
feature to tidy up your commits before making them public.

5. Push your topic branch up to your fork:

```bash
git push origin <topic-branch-name>
```

6. [Open a Pull Request](https://help.github.com/articles/using-pull-requests/)
with a clear title and description.

7. If you haven't updated your pull request for a while, you should consider
rebasing on master and resolving any conflicts.

**IMPORTANT**: _Never ever_ merge upstream `master` into your branches. You
should always `git rebase` on `master` to bring your changes up to date when
necessary.

```bash
git checkout master
git pull upstream master
git checkout <your-topic-branch>
git rebase master
```


#### Running the Guides Locally

Generating guides requires two separate running processes. One watches the files for changes, and will regenerate the files as they change. The other serves the files so they can be viewed in a web browser.

In the first terminal, run:

```console
mix deps.get
mix docs.watch
```

In the second terminal, run:

```console
python -m SimpleHTTPServer
```

Then open [http://localhost:8000/doc/overview.html](http://localhost:8000/doc/overview.html) to view the generated docs.

Thank you for your contributions!
