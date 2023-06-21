# schedule-to-html
Convert spreadsheet to html webpage with schedule

Utility that I use to create an HTML page from a schedule for Cosplay America.

Not very well documented sorry.

## Run:

desc_tbl --input input/spreadsheet.xlsx --output output/ [options]

or

```
desc_tbl --input input/spreadsheet.xlsx [common options] \
    -- --output a/ [optionset a]                         \
    -- --option b/ [optionset b] ...
```

The options before the first -- are common state, then each group of options split by '--' are processed
separately. Note there is a bug where --show/hide-paneltype and --show/hide-room propagate to the
subsequent option sets. See dump_flyers for an example of this being used to generate a bunch of
versions of files with a single run.

## Options:

| Option                       | Meaning                                                                |
| ---------------------------- | ---------------------------------------------------------------------- |
| --copies _number_            | How many copies in the same html                                       |
| --desc-by-guest              | Arrange descriptions by guest, showing just guest                      |
| --desc-by-presenter          | Arrange descriptions by presenters, implies --desc-by-guest            |
| --desc-everyone-together     | Do not sort descriptions by guest or presenters, default               |
| --desc-form-div              | Output descriptions in paragraphs. _Needs CSS work_                    |
| --desc-form-table            | Output descriptions in a table. Default                                |
| --desc-loc-last              | Output descriptions after all grids                                    |
| --desc-loc-mixed             | Output descriptions between grids. Default                             |
| --embed-css                  | Embed any CSS files in the generated HTML, default if --style          |
| --end-time _time_            | Exclude any panels after _time_                                        |
| --everyone                   | Show descriptions for all presenters, default                          |
| --file-all-days              | Do not generate a file for each day, default                           |
| --file-all-rooms             | Do not generate a file for each room                                   |
| --file-by-day                | Generate separate file for each day                                    |
| --file-by-guest              | Generate a file for each guest                                         |
| --file-by-presenter          | Generate a file for each presenter, implies --file-by-guest            |
| --file-by-room               | Generate a file for each room                                          |
| --file-everyone-together     | Do not generate a file for each guest or presenters, default           |
| --help                       | Display options                                                        |
| --help-markdown              | Generate option summary for README.md                                  |
| --hide-av                    | Do not include notes for Audio Visual, default                         |
| --hide-breaks                | Hide descriptions for breaks, default                                  |
| --hide-day                   | Does not include a column for week day, default                        |
| --hide-descriptions          | Does not include description, implies --show-grid                      |
| --hide-difficulty            | Hide difficulty information                                            |
| --hide-free                  | Hide descriptions for panels that are free                             |
| --hide-grid                  | Does not includes the grid, implies --show-description                 |
| --hide-paneltype _paneltype_ | Hide paneltype even if normally shown                                  |
| --hide-premium               | Hide descriptions for panels that are premium                          |
| --hide-room _room_           | Hide room, even if normally shown                                      |
| --hide-unused-rooms          | Only include rooms that have events scheduled, default                 |
| --inline-css                 | Link to CSS files in the generated HTML, default unless --style        |
| --input _file_.txt           | Source data for schedule, UTF-16 spreadsheet                           |
| --input _file_.xlsx          | Source data for schedule, xlsx file                                    |
| --input _file_.xlsx:_num_    | May have a _num_ suffix to select a sheet by index                     |
| --just-guest                 | Hide descriptions for other presenters, implies --file-by-guest        |
| --just-presenter             | Hide descriptions for other presenters, implies --file-by-presenter    |
| --mode-flyer                 | Generate flyers, default mode                                          |
| --mode-kiosk                 | Generate files for use in a realtime kiosk                             |
| --mode-postcard              | Output for use in schedule postcards                                   |
| --no-desc-by-guest           | Do not arrange by guest, exclude guest if --desc-by-presenter is given |
| --no-desc-by-presenter       | Do not arrange descriptions by presenter                               |
| --no-file-by-guest           | Do not generate a file for each guest                                  |
| --no-file-by-presenter       | Do not generate a file for each presenter                              |
| --no-section-by-guest        | Do not generate a section for each guest                               |
| --no-section-by-presenter    | Do not generate a section for each presenter                           |
| --output _name_              | Output filename or directory if any --file-by-... used                 |
| --room _name_                | Focus on matching room, may be given more than once                    |
| --section-all-days           | Do not generate a section for each day, default                        |
| --section-all-rooms          | Do not generate a section for each room                                |
| --section-by-day             | Generate separate section for each day                                 |
| --section-by-guest           | Generate a section for each guest                                      |
| --section-by-presenter       | Generate a section for each presenter, implies --section-by-guest      |
| --section-by-room            | Generate a section for each room                                       |
| --section-everyone-together  | Do not generate a section for each guest or presenters, default        |
| --show-all-rooms             | Show rooms even if they have no events scheduled                       |
| --show-av                    | Include notes for Audio Visual                                         |
| --show-breaks                | Includes descriptions for breaks                                       |
| --show-day                   | Include a column for week day                                          |
| --show-descriptions          | Includes panel descriptions, implies --hide-grid                       |
| --show-difficulty            | Show difficulty information, default                                   |
| --show-free                  | Show descriptions for panels that are free, implies --hide-premium     |
| --show-grid                  | Includes the grid, implies --hide-description                          |
| --show-paneltype _paneltype_ | Show paneltype even if normally hidden                                 |
| --show-premium               | Show descriptions for panels that are premium, implies --hide-free     |
| --show-room _room_           | Show room, even if normally hidden                                     |
| --split                      | Implies --split-timeregion if --split-day not set                      |
| --split-day                  | Only split once per day                                                |
| --split-timeregion           | Split the grids by SPLIT time segments, default                        |
| --start-time _time_          | Exclude any panels before _time_                                       |
| --style _filename_           | CSS file to include, may be given more than once, implies --embed-css  |
| --style +color[=_set_]       | Use colors from the panel type sheet, _set_ is "Color" if not given.   |
| --style all:_style_          | Apply style to all media                                               |
| --style screen:_style_       | Apply style to when viewing on a screen, normal web view               |
| --style print:_style_        | Apply style to when printing, normal web view                          |
| --title _name_               | Sets the page titles                                                   |
| --unified                    | Do not split table by SPLIT time segments or days                      |

### Aliases

| Alias                    | Equivalent to option            |
| ------------------------ | ------------------------------- |
| --desc-by-panelist       | --desc-by-presenter             |
| --descriptions           | --show-descriptions             |
| --file-by-panelist       | --file-by-presenter             |
| --flyer                  | --mode-flyer                    |
| --grid                   | --show-grid                     |
| --just-descriptions      | --show-descriptions --hide-grid |
| --just-free              | --show-free --hide-premium      |
| --just-grid              | --show-grid --hide-descriptions |
| --just-panelist          | --just-presenter                |
| --just-premium           | --show-premium --hide-free      |
| --kiosk                  | --mode-kiosk                    |
| --no-desc-by-panelist    | --no-desc-by-presenter          |
| --no-embed-css           | --inline-css                    |
| --no-file-by-day         | --file-all-days                 |
| --no-file-by-panelist    | --no-file-by-presenter          |
| --no-file-by-room        | --file-all-rooms                |
| --no-inline-css          | --embed-css                     |
| --no-section-by-day      | --section-all-days              |
| --no-section-by-panelist | --no-section-by-presenter       |
| --no-section-by-room     | --section-all-rooms             |
| --no-separate            | --desc-loc-mixed                |
| --no-split               | --unified                       |
| --postcard               | --mode-postcard                 |
| --section-by-panelist    | --section-by-presenter          |
| --separate               | --desc-loc-last                 |
| --show-unused-rooms      | --show-all-rooms                |
| --split-half-day         | --split-timeregion              |

If no option is specified for either grids or descriptions both are included.

### CSS files

Styles default to the files in the css directory. They may be prefixed to all:,
screen:, or print: to restrict the style to the media. The special styles
"+color" and "+color=_type_" are used to automatically generate styles based
on the matching field in the paneltype sheet.

Example:
* common.css -- Has default colors
* guest4x6.css -- For printing to 4x6 cards, consider --postcard
* landscape.css -- Printing is set to landscape mode
* portrait.css -- Printing is set to portrait mode
* poster20x30.css -- Printing to 20x30 posters
* poster30x20.css -- Printing to 30x20 posters
* poster30x20v2.css -- 30x20 with smaller font size, more columns
* poster30x20v3.css -- 30x20 with larger font size, more columns, page breaks
* screen:+color -- Color the panels when viewing in a browser
* print:+color=BW -- Use black and white for panels when printing

## Important Spreadsheet contents

All timestamps are in the form of M/DD/YYYY HH:MM where, M is month 1-12, D is
day of month 1-31, YYYY is the year, HH is the hour ( 0-23 ), MM is the minute.

Space in header names are treated as underscores.

If opening a XLSX file, this should be the first sheet, or the sheet can be
specified by number with an :# after the file name.

Spaces or underscores may be used to separate words in field names.

### Field summary

| Field Name    | Required               | Contents                                                                                                                                       | Example                           |
| ------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Uniq ID       | Yes                    | Two letter unique id, plus 3 digit panel id, plus optional suffix, UNIQUE ID must match PanelTypes, SPLIT is special, ZZ for unlisted time     | ZZ123                             |
| Changed       |                        | Timestamp of change                                                                                                                            | 6/25/22 6:00 PM                   |
| Name          | Yes                    | Name of the panel as will appear in the program                                                                                                | A Sample Panel                    |
| Room          | If Scheduled           | Name of the room, must match the Rooms sheet if used. Multiple rooms may be given separated by commas                                          | Programming 1                     |
| Original Time | If moved               | If the time of the panel was changed, original time so that I can find it in program to remove old copy                                        | 6/25/22 6:00 PM                   |
| Start Time    | If Scheduled           | Start time of panel, make blank to "unschedule" a panel instead of just deleting it                                                            | 6/25/22 6:00 PM                   |
| Duration      | If Scheduled           | Duration of the panel                                                                                                                          | 1:00                              |
| Description   | If Scheduled           | Description of the panel                                                                                                                       | A Panel about panels              |
| Note          |                        | Additional notes that will appear in the program verbatim highlight                                                                            | Note: This is not really a panel  |
| AV Notes      |                        | Information for Audio/Visual Setup. Will show if --show-av argument is used                                                                    | Mic: 2 handheld Video: HDMI Stage |
| Difficulty    |                        | Number representing the difficulty of the panel                                                                                                | 1                                 |
| Cost          |                        | For paid panels, how much costs to attend                                                                                                      | $35                               |
| Seats Sold    | If premium workshop    | How many seats have been already sold                                                                                                          | 3                                 |
| Capacity      | If premium workshop    | How many seats are available                                                                                                                   | 23                                |
| Full          |                        | If the panel is full. TODO support Seats_Sold and Capacity                                                                                     | Yes                               |
| Hide Panelist |                        | Set no non-blank (such as "Yes") if panelist names are not to be shown for the description                                                     | Yes                               |
| Alt Panelist  |                        | Replacement text for the panelist names in the description instead of computing automatically                                                  | Mystery Guest                     |
| G:Name=Group  |                        | Guest with name of Name, member of group. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted            | Yes                               |
| G:Name        |                        | Guest with name of Name. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted                             | *                                 |
| G:Other       |                        | Additional guests that don't have a header, you can just add rows if you want more columns                                                     | One Shot Wonder                   |
| S:Name=Group  |                        | Staff with name of Name, member of group. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted            | Yes                               |
| S:Name        |                        | Staff with name of Name. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted                             | Yes                               |
| S:Other       |                        | Additional staff that don't have a header, you can just add rows if you want more columns                                                      | Jane Doe, John Smith              |
| I:Name=Group  |                        | Invited panelist with name of Name, member of group. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted | *                                 |
| I:Name        |                        | Invited panelist with name of Name. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted                  | Yes                               |
| I:Other       |                        | Additional invited panelist that don't have a header, you can just add rows if you want more columns                                           | Jane Doe, John Smith              |
| P:Name=Group  |                        | Fan panelist with name of Name, member of group. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted     | *                                 |
| P:Name        |                        | Fan panelist with name of Name. Set to non-blank ( such as "Yes" ) if required to be present, "*" if present but unlisted                      | Yes                               |
| P:Other       |                        | Additional panelist that don't have a header, you can just add rows if you want more columns                                                   | Jane Doe, John Smith              |
| Kind          | If no PanelTypes sheet | Panel kind based on prefix, if there is a PanelTypes sheet this can be computed from Uniq ID                                                   | Workshop                          |
| Room Idx      | If no Rooms sheet      | Id of room, used for sorting, 100+ are hidden                                                                                                  |                                   |
| Real Room     | If no Rooms sheet      | Hotel Room name                                                                                                                                |                                   |

### Uniq Id

This is the ID of the panel, typical it should be unique, though the system
will still work if IDs are shared. The first two characters of the unique id
are used to determine the panel type. Note that the id is consider based on
all the characters so GW032 and FP032 are different panels even if both have
the number 32.

Examples

* GP032 - This is a guest panel 32.
* FP032 - This is fan panel 32.
* GW019A - This is the first offering of GW019
* GW019B - This is the second offering of GW019
* GW020P1 - This is part 1 of GW020
* GW020P2 - This is part 2 of GW020
* GW020P3 - This is part 3 of GW020
* SPLIT01 - Special panel used to indicate when to split the grid
* BREAK01 - Special panel used to indicate a convention wide break

### Changed

The optional changed column is used to track updates.

Example: 3/05/2023 1:59 PM

### Name

The name of the panel

Examples

* The Grand Gala
* Closing Ceremonies
* Affixing Sans Glue

### Room

The room name, should match the name used in room sheet. Can be the "Room Name", "Hotel Room" or "Long Name".

Example:

* Main - A panel that occurs in the main room
* Programming 1 - A panel that occurs in programming 1.
* Candlewood - A panel that occurs in candlewood.
* Main, Programming 1 - A panel that is split between main and programming 1.

### Original Time

For record keeping if a panel was moved, this option field can be used to
note the original time that the panel was schedule to make it easier to find.

### Start Time

The time at which a panel starts. For excel sheets this should be a time/date
stamp. Internally tracked as seconds since the epoch.

Examples:

* 6/23/2023 7:00 PM
* 6/26/2023 9:00 PM

### Duration

How long the panel last, in hours and minutes.

Examples:

* 0:30 - A thirty minute panel
* 1:00 - A one hour panel
* 2:30 - A two and half hour panel

### Description

Description of the panel, will appear in the descriptions output.

Example:

* Learn how to fix broken props with gum, and duck tape. Ann E Mouse will
  show you several useful tricks for last minute costume repairs.

### Note

Additional note to display before the description. Highlighted.

Example:

* You will need to bring glue to this panel.

### AV Notes

Notes for audio / visual or behind the scenes. Will only be output if the 
--show-av option is used.

Example:

* Mic: 1 Table, 2 Wireless. Document projector to show needle work.

### Difficulty

Difficulty for the panel, normally used for workshops. Will be displayed
as part of the description. No pre-defined values, so can use 1-5, or
Easy, etc.

Example:
* 1
* 5
* Easy
* Beginning
* Intermediate
* Challenging

### Cost

How much does this panel cost to attend. May be left blank

### Seats sold

How many seats for a limited panel have sold / been reserved. Currently unused.

### Capacity

How many totals seats are their for this panel. Currently unused.

### Full

Marks a panel as full, will apply special styling to full panels. Future: May be implied if Seats Sold >= Capacity.

### Hide Panelist

If this field is set for a panel, no panelist information will be displayed.

Allows a custom form for the panelist to be specified.

### Panelist

#### Hide Panelist
The "Hide Panelist" field is used to prevent the panelists from being shown
in the grid and description if it is not blank. Using an "*" is another way
to hide panelist.

Example:

* YES
* 

### Alt Panelist

The "Alt Panelist" field is used to include text to display as the panelist
instead of computing from the other fields. If you have a panelist that only
does one or two panels it is better to use the _Kind_:Other fields.

Example:

* Mystery Guest

### Other panelist columns: _Kind_:_Name_=_Group_

The syntax for panelist field name is _Kind_:_Name_=_Group_, _Kind_:_Name_,
or _Kind_:Other

The following kinds are currently supported

* G - Guest
* S - Staff
* I - Invited panelist
* P - Fan panelist

_Name_ is the name of the guest as shown. If the name is other, the contents of
the cell should be a list of names separated by commas.

_Group_ is the group that guest belongs to, if all members of a group are
attending they will be listed as a group instead of individually. If double
equals are used the group name will always be listed, and if only one member
they will be displayed in parenthesis.

For each of these columns, if the contents are not blank, the panelist is
attending, use asterisk "*" to have some one present but not listed.

### Kind

See the PanelTypes sheet. This should only be used if a PanelTypes sheet is
not used, and other way to specify panel kind.

### Room Idx

See the Rooms Sheet. This should only be used if a Rooms sheet is not used,
and other way to specify the "Sort Key".

### Real Room

See the Rooms Sheet. This should be only used if a Rooms sheet is not used,
and other way to specify the "Hotel Room".

## Rooms Sheet

A sheet named "Rooms" can be used to make the room name to hotel room name, and
event room name and control sorting

| Field      | Meaning                                                                                       |
| ---------- | --------------------------------------------------------------------------------------------- |
| Room Name  | Name of the room, should make the name in the schedule sheet                                  |
| Hotel Room | Name of the hotel room, shown if different then long name                                     |
| Long Name  | Name of the room to show above the hotel name                                                 |
| Sort Key   | The order panels will appear in the output. Numbers 100 or greater are special and not known. |

If "Hotel Room" and "Long Name" are the same only one is shown.

### Splitting the grid

The special SPLIT... rooms are used to control where the grid splits

Example of what splits are defined like in the main schedule.

| Uniq ID | Name               | Room       | Start Time      |
| ------- | ------------------ | ---------- | --------------- |
| SPLIT01 | Friday Morning     | SPLITDAY   | 6/24/2022 08:00 |
| SPLIT02 | Friday Afternoon   | SPLITNIGHT | 6/24/2022 18:00 |
| SPLIT03 | Saturday Morning   | SPLITDAY   | 6/25/2022 08:00 |
| SPLIT04 | Saturday Afternoon | SPLITNIGHT | 6/25/2022 18:00 |
| SPLIT05 | Sunday             | SPLITDAY   | 6/26/2022 08:00 |

The special SPLIT rooms don't have to be defined in the Rooms sheet, but
I tend to for completeness. Any naming being with SPLIT works, only
SPLITDAY has an extra meaning.

If the --split-day switch is used, only SPLITDAY will split the grid and
other splits will be ignored. In that case only the first word of the
"panel" name will be used for the split.

| Room Name  | Sort Key | Hotel Room | Long Name |
| ---------- | -------- | ---------- | --------- |
| SPLITDAY   | 101      | SPLIT      | SPLIT     |
| SPLITNIGHT | 101      | SPLIT      | SPLIT     |

## PanelTypes sheet

Mapping between UniqID prefix and panel types.

| Field       | Meaning                                  |
| ----------- | ---------------------------------------- |
| Prefix      | Two letter prefix of Uniq ID             |
| Panel Kind  | Full name of the panel kind              |
| Is Break    | Type is used for breaks                  |
| Is Café     | Type is used for café panels             |
| Is Workshop | Type is used for workshops               |
| Color       | Color to be used for the panel           |
| BW          | Alternate color to be used for the panel |

Examples:

| Uniq ID | Name         | Room   | Start Time      | Duration | Description        | G:John Smith |
| ------- | ------------ | ------ | --------------- | -------- | ------------------ | ------------ |
| DE01    | How to panel | Panel1 | 6/24/2022 08:00 | 01:00    | Learn how to panel | Yes          |

| Prefix | Panel Kind |
| ------ | ---------- |
| DE     | DEMO       |


## Examples

Wide landscape
```
desc_tbl \
    --style license-fonts.css \
    --style common.css \
    --style screen.css \
    --style screen:+color \
    --style screen:color.css \
    --style print.css \
    --style print:+color=BW \
    --style print:bw.css \
    --style print:landscape_wide.css \
    --input input/Test.xlsx \
    --output output/ \
    --split-day \
    --separate \
    --inline-css
```

Guest output
```
desc_tbl \
    --style license-fonts.css \
    --style common.css \
    --style screen.css \
    --style screen:+color \
    --style screen:color.css \
    --style print.css \
    --style print:+color=BW \
    --style print:bw.css \
    --style print:landscape.css \
    --input input/Test.xlsx \
    --output output/guests \
    --file-by-presenter \
    --split-day \
    --separate \
    --just-guest
```

Kiosk output
```
./desc_tbl \
    --input input/Test.xlsx \
    --output output/kiosk/ \
    --mode-kiosk
```

Room output

## Container

There is a devcontainer set up for this repository to make it easier to use which launches
a docker compose container with a debian based perl instance.

### .devcontainer subdirectory

| File                          | Contents                          |
| ----------------------------- | --------------------------------- |
| **devcontainer.json**         | Dev Container definition          |
| **docker-compose.extend.yml** | Defines persistent home directory |

### container subdirectory

| File                   | Contents                                               |
| ---------------------- | ------------------------------------------------------ |
| **userhome**           | Default user home directory                            |
| **docker-compose.yml** | Docker compose file defines schedule-to-html service   |
| **Dockerfile**         | Container definition for the schedule-to-html service. |

## Licensing:

For desc_tbl see LICENSE

Files in .devcontainer/container may have their own license
