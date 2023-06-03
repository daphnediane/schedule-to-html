# schedule-to-html
Convert spreadsheet to html webpage with schedule

Utility that I use to create an HTML page from a schedule for Cosplay America.

Not very well documented sorry.

## Run:

desc_tbl --input input/spreadsheet.xlsx --output output/

## Options:

| Option                    | Meaning                                                                |
| ------------------------- | ---------------------------------------------------------------------- |
| --desc-alt-form           | Change how descriptions are output _Needs CSS work_                    |
| --desc-by-columns         | _Reserved for future_                                                  |
| --desc-by-guest           | Arrange descriptions by guest, showing just guest                      |
| --desc-by-presenter       | Arrange descriptions by presenter, implies --desc-by-guest             |
| --desc-table-form         | Do not change how descriptions are output, default                     |
| --descriptions            | _Alias for --descriptions_                                             |
| --embed-css               | Embed any CSS files in the generated HTML, default                     |
| --end-time _time_         | Exclude any panels after _time_                                        |
| --file-all-days           | Do not generate a file for each day, default                           |
| --file-all-room           | Do not generate a file for each room                                   |
| --file-by-day             | Generate separate file for each day                                    |
| --file-by-guest           | Generate a file for each guest                                         |
| --file-by-presenter       | Generate a file for each presenter, implies --file-by-guest            |
| --file-by-room            | Generate a file for each room                                          |
| --flyer                   | _Alias for --mode-flier_                                               |
| --grid                    | _Alias for --show-grid_                                                |
| --hide-av                 | Do not include notes for Audio Visual                                  |
| --hide-day                | Does not include a column for week day, default                        |
| --hide-descriptions       | Does not include description, implies --show-grid                      |
| --hide-difficulty         | Hide difficulty information                                            |
| --hide-free               | Hide descriptions for panels that are free                             |
| --hide-grid               | Does not includes the grid, implies --show-description                 |
| --hide-premium            | Hide descriptions for panels that are premium                          |
| --hide-unused-rooms       | Only include rooms that have events scheduled                          |
| --inline-css              | _Alias for --embed-css_                                                |
| --input _file_.txt        | Source data for schedule, UTF-16 spreadsheet                           |
| --input _file_.xlsx       | Source data for schedule, xlsx file                                    |
| --input _file_.xlsx:_num_ | May have a _num_ suffix to select a sheet by index                     |
| --just-free               | _Alias for --hide-premium_                                             |
| --just-guest              | _Alias for --just-guest_                                               |
| --just-premium            | _Alias for --hide-free_                                                |
| --just-presenter          | Hide descriptions for other presenters, implies --file-by-guest        |
| --kiosk                   | _Alias for --mode-kiosk_                                               |
| --mode-flyer              | Default generation mode                                                |
| --mode-kiosk              | Generate files for use in a realtime kiosk                             |
| --mode-postcard           | Output for use in schedule postcards                                   |
| --no-desc-by-columns      | _Reserved for future_                                                  |
| --no-desc-by-guest        | Do not arrange by guest, exclude guest if --desc-by-presenter is given |
| --no-desc-by-presenter    | Do not arrange descriptions by presenter                               |
| --no-embed-css            | Link to CSS files in the generated HTML                                |
| --no-file-by-guest        | Do not generate a file for each guest                                  |
| --no-file-by-presenter    | Do not generate a file for each presenter                              |
| --no-inline-css           | _Alias for --no-embed-css_                                             |
| --no-postcard             | _Alias for --no-mode-postcard_                                         |
| --no-separate             | Do not change the placement of descriptions between grids              |
| --no-split                | _Alias for unified_                                                    |
| --output _name_           | Output filename or directory if any --file-by-... used                 |
| --postcard                | _Alias for --mode-postcard_                                            |
| --room _room_             | Focus on matching room, may be given more than once                    |
| --separate                | Put descriptions after all grids instead of after each grid            |
| --show-all-rooms          | Show rooms even if they have no events scheduled                       |
| --show-av                 | Include notes for Audio Visual                                         |
| --show-day                | Include a column for week day                                          |
| --show-descriptions       | Includes panel descriptions, implies --hide-grid                       |
| --show-difficulty         | Show difficulty information, default                                   |
| --show-free               | Show descriptions for panels that are free, implies --hide-premium     |
| --show-grid               | Includes the grid, implies --hide-description                          |
| --show-premium            | Show descriptions for panels that are premium, implies --hide-free     |
| --show-unused-rooms       | _Alias for --show-all-rooms_                                           |
| --split                   | Implies --split-time-region, unless --split-day                        |
| --split-day               | Only split once per day                                                |
| --split-half-day          | _Alias for --split-time-region_                                        |
| --split-time-region       | Split the grids by SPLIT time segments, default                        |
| --start-time _time_       | Exclude any panels before _time_                                       |
| --style _file_            | CSS file to include, may be given multiple times, implies --embed-css  |
| --title _name_            | Sets the page titles                                                   |
| --unified                 | Do not split table by SPLIT time segments or days                      |

If no option is specified for either grids or descriptions both are included.

## CSS files

* common.css -- Has default colors
* guest4x6.css -- For printing to 4x6 cards, consider --postcard
* landscape.css -- Printing is set to landscape mode
* portrait.css -- Printing is set to portrait mode
* poster20x30.css -- Printing to 20x30 posters
* poster30x20.css -- Printing to 30x20 posters
* poster30x20v2.css -- 30x20 with smaller font size, more columns
* poster30x20v3.css -- 30x20 with larger font size, more columns, page breaks

## Important Spreadsheet contents

All timestamps are in the form of M/DD/YYYY HH:MM where, M is month 1-12, D is
day of month 1-31, YYYY is the year, HH is the hour ( 0-23 ), MM is the minute.

Space in header names are treated as underscores.

If opening a XLSX file, this should be the first sheet, or the sheet can be
specified by number with an :# after the file name.

Spaces or underscores may be used to separate words in field names.

Normal Columns:

| Field Name    | Required               | Contents                                                                                                                                       | Example                           |
| ------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Uniq ID       | Yes                    | Two letter unique id, plus 3 digit panel id, UNIQUE ID must match PanelTypes, SPLIT is special, ZZ for unlisted time                           | ZZ123                             |
| Changed       | After first draft      | Timestamp of change                                                                                                                            | 6/25/22 6:00 PM                   |
| Name          | Yes                    | Name of the panel as will appear in the program                                                                                                | A Sample Panel                    |
| Room          | If Scheduled           | Name of the room, must match the Rooms sheet if used                                                                                           | Programming 1                     |
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

Panelist Columns

The syntax for panelist columns is _Kind_:_Name_=_Group_, _Kind_:_Name_, or _Kind_:Other

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

## Rooms Sheet

A sheet named "Rooms" can be used to make the room name to hotel room name, and
event room name and control sorting

* Room_Name - Name of the room, should make the name in the schedule sheet
* Hotel_Room - Name of the hotel room, shown if different then long name
* Long_Name - Name of the room to show above the hotel name
* Sort_Key - The order panels will appear in the output. Numbers 100 or
  greater are special and not known.

If Hotel_Room and Long_Name are the same only one is shown.

# Splitting the grid

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

* Prefix - Two letter prefix of Uniq ID
* Panel Kind - Full name of the panel kind

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
    --style screen:+color=BW \
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
    --style screen:+color=BW \
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
