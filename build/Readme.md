# Generating the docs: 

This directory uses [pandoc](), a universal document converter, to build the markdown files into a pdf. Due to regulatory concerns LME cannot release a pdf directly, but you can utilize the following script to build the markdown docs into a pdf so you can use them offline if desired.

In our testing we utilized the macos package manager [homebrew](https://brew.sh/) to install our packages.

## Installing pandoc

After installing homebrew make sure to install mactex:
```bash
brew install mactex
```
This is a large file that simplyfies compiling everything.

Finally install pandoc: [link](https://pandoc.org/installing.html)  
```bash
brew install pandoc
```

### Installing on other platforms
Other operating systems and their respective latex/pandoc packages have not been tested nor will LME support them in the future. Since not every organization has access to a MacOS operating system, but might wish to compile the docs anyway, please reachout to LME and the team will attempt to help you compile the docs into a pdf. Any operating system with a latex package and pandoc executable should suffice.  There are several other ways to convert github flavored markdown to pdf if you search them online and want to compile using a different method than provided here.

## Compiling: 
This command below will compile the markdown docs on MacOS from the homebrew install pandoc/mactex packages:
```bash
$ pandoc --from gfm --pdf-engine=lualatex -H ./build/setup.tex -V geometry:margin=1in --highlight-style pygments -o docs.pdf -V colorlinks=true -V linkcolor=blue --lua-filter=./build/emoji-filter.lua --lua-filter=./build/makerelativepaths.lua --lua-filter=./build/parse_breaks.lua --table-of-contents --number-sections --wrap=preserve --quiet -s $(cat ./build/includes.txt)
```

A successful compilation will output the `docs.pdf` file, a pdf of all the docs. There is a small bug where the `troubleshooting.md` table does not display as expected, so if you want the notes in the table offline, we suggest you record the information manually, OR submit a pull request that fixes this bug.
