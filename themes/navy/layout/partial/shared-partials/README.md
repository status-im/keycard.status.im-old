# status.im-partials

Global parts of the Status web presence which are shared between all sites.

It is expected that this repo should be included into other status static websites, using gits **submodule feature**.

### Adding this repo to an existing/new status static website.

First, `cd` down into the partials folder of the theme in use (since the command to add a submodule adds it relative to where the command is running).

Next we can run this command: `git submodule add https://github.com/status-im/status.im-partials shared-partials`
What this does is add the repo as a submodule, effectively cloning it, in this case into a folder '**shared-partials**'.

Done! Now other partials in that project can reference (with relative paths - at least until hexo version 4) the partials contained in the newly created **shared-partials** folder.
This would be done usuing hexos partial syntax:
```
{{ partial('partial/shared-partials/partials/footer') }}
```

### Working-on/editing the partials in this repo

First you edit the files and push them up into the repo, then you'll need to update the other static websites which include this repo as a submodule.

#### 1. Editing the files

The partials can be edited by either cloning this repo as it is and pushing it up as per any normal git workflow
OR
even better you can just work on them within whatever other repo you have added this one to as a submodule. This makes testing as you go possible and is the recommended workflow.

In that case cd down into the correct place (following on from the above example: the *shared-partials* folder), and git away as usual.
Note: git submodule repos are added with detached heads by default, so first run `git checkout master` (from within the submodule repo) before commiting :)

#### 2. Updating other sites that makes use of these shared partials

From the root of each other website, run the command `git submodule update --recursive --remote`. It will pull down any changes to the submodule repo.

Note: That will update all and any submodules within the document tree.

It is expected that other static sites add the above command as an .npm script (eg. "update-submodules") to make things simpler & also aid integrating with CI/CD.

### Assumptions

These shared partials were developed to be used in *hexo* projects.

### Notes

We went with submodules over subtrees, so that we could 'clone' this repo into specific folders, that way the contained partials could be referenced relatively.