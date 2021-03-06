# installimage - Style Guide

---

## Contents
+ [Indentation Guidelines](#indentation-guidelines)
+ [Multiline Output to File](#multiline-output-to-file)
+ [Functions](#functions)
+ [Escaping](#escaping)
+ [Preferred Usage of Bash Builtins](#preferred-usage-of-bash-builtins)
+ [Multiple Parameter Validation](#multiple-parameter-validation)
+ [Brackets Notation](#brackets-notation)
+ [Comments in Files](#comments-in-files)
+ [Variable Convention](#variable-convention)
+ [Inspiration](#inspiration)

---

## Indentation Guidelines
we use two whitespaces for Indentation, and no hard tabs. This results in the following vim settings:
```
set tabstop=2
set shiftwidth=2
set expandtab
set softtabstop=2
```

## Multiline Output to File
Group the output of multiple commands with braces and redirect this once into a file. Also do not redict STDERR to a debugfile, this is useless for echos (`} > "$NETWORKFILE" 2>> "$DEBUGFILE"`). Here is a bad example:
```bash
echo "### $COMPANY - installimage" > "$CONFIGFILE"
echo "# Loopback device:" >> "$CONFIGFILE"
echo "auto lo" >> "$CONFIGFILE"
echo "iface lo inet loopback" >> "$CONFIGFILE"
echo "" >> "$CONFIGFILE" 2>> "$DEBUGFILE"
```

The `{` and the `}` have to be in own lines and the content between them indented by two spaces. Here is another bad example:
```bash
{ echo "### $COMPANY - installimage"
echo "# Loopback device:"
echo "auto lo"
echo "iface lo inet loopback"
echo "" } > "$CONFIGFILE" 2>> "$DEBUGFILE"
```

Besides the formatting, this also redirects STDERR to `$DEBUGFILE`, this is useless because the brackets only encapsulate echos, you only need the redirect if you do something else that could actually fail.

A good example for this is:
```bash
{
  echo "### $COMPANY - installimage"
  echo "# Loopback device:"
  echo "auto lo"
  echo "iface lo inet loopback"
  echo ""
} > "$CONFIGFILE"
```

## Functions
Functions should be pure if possible, e.g. the same input produces the same output and they should not access global variables.
This makes reasoning about correctness much easier.

## Escaping
We don't want dirty escaping for variables in `echo`, we should prefer printf in these cases, here is a bad example:
```bash
echo -e "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$2\", ATTR{dev_id}==\"0x0\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"$1\"" >> $UDEVFILE
```

and here a good one:
```bash
printf 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%s", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="%s"\n' "$2" "$1" >> "$UDEVFILE"
```

## Preferred Usage of bash builtins
For security and performance reasons we should use bash builtins wherever possible. Bad example for iterations:
```bash
for i in $(seq 1 $COUNT_DRIVES) ; do
  if [ $SWRAID -eq 1 -o $i -eq 1 ] ;  then
    local disk="$(eval echo "\$DRIVE"$i)"
    execute_chroot_command "grub-install --no-floppy --recheck $disk 2>&1"
  fi
done
```

and a good example:
```bash
for ((i=1; i<="$COUNT_DRIVES"; i++)); do
  if [ "$SWRAID" -eq 1 ] || [ "$i" -eq 1 ] ;  then
    local disk; disk="$(eval echo "\$DRIVE"$i)"
    execute_chroot_command "grub-install --no-floppy --recheck $disk 2>&1"
  fi
done
```

## Multiple Parameter Validation
Always use seperate testcases for params, bad example:
```bash
if [ "$1" -a "$2" ]; then
```

good example:
```bash
if [ -n "$1" ] && [ -n "$2" ]; then
```

## Brackets Notation
We want to avoid useless whitespace in general, for example in brackets. here is a bad awk example:
```bash
awk '{ print $2 }'
```

and the correct one:
```bash
awk '{print $2}'
```

## Comments in Files
There are two kinds of comments, those that contain higher level descriptions should be easily and clearly visible --> Empty comment line before and after. Commented code lines are without any empty comment lines.

## Variable Convention
we've got two types of varibles:
* global ones
    * are uppercase
    * explictly exported

* local variables
    * are lowercase
    * used in functions
    * defined with local

Try to use local vars whereever possible. Complex variable names (consisting of multiple names) are always connected with a _, for example `COUNT_DRIVES` as a global one or `count_drives` as a local one.

Variables that contain an array:
Arrays should be indicated by name and the loop variable should resamble this. Good example (take a look at the singular/plural here):
```bash
declare -a harddrives
declare -i harddrives_number="${#harddrives[@]}"
if [[ $harddrives_number -gt 0 ]]; then
  for harddrive in harddrives; do
    echo "$harddrive"
  done
fi
```

## Inspiration
This is loosely based on:
+ [Bash Hackers Style Guide](http://wiki.bash-hackers.org/scripting/style)
+ [Googles Shell Style Guide](https://google.github.io/styleguide/shell.xml)
