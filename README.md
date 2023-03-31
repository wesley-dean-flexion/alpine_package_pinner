# alpine\_package\_pinner

This will consume a text file containing a list of Alpine packages
and write a versioned list to a "lock" file that `apk` can use to
install packages.

## Running

By default, the script will read ./apk.txt and write to ./apk-lock.txt
safely (i.e., if the script is not able to read the contents of the
source file or if no versions could be found (typically implying
something else being wrong, such as an OS release mismatch), then
the output file will not be overwritten.

The script can use the same filename for both input and output;
that is, on the input side, it'll filter out the version information
while the output won't be written to the filename until the entire
input has been read.  So, this works:

```bash
./alpine_package_pinner.bash --input apk.txt --output apk.txt
```

### Running on non-Alpine

If the `branch` isn't provided (as an environment variable), then the
script will attempt to determine the release of Alpine that's running.

The script doesn't need to be run from Alpine Linux.. if the Alpine
release is provded via the `branch` environment variable.  So, this
will run from a system running Ubuntu:

```bash
branch=v3.17 ./alpine_package_pinner.bash
```

### Determining Package Versions

The Alpine website is queried and `xmllint` is used to parse out
the results of what would have been a web-submitted query.  If
the site changes (i.e., if there is no longer a `<td>` tag with
a `class` of `version`) then this script will break.
