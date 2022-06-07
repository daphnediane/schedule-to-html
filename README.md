# schedule-to-html
Convert spreadsheet to html webpage with schedule

Utility that I use to create an HTML page from a schedule for Cosplay America.

Not very well documented sorry.

Quick start:

And place spreadsheet in the input directory.

## Run:

desc_tbl --input input/spreadsheet.txt --output output/

## Options:
```
  --day           Include a column for week day
  --description   Includes panel descriptions, implies --no-grid
  --file-by-day   Have a file for each day
  --file-by-room  Have a file for each room
  --file-by-guest Create a file per guest with their panels highlighted
  --grid          Includes the grid, implies --no-description
  --hide-unused   Only include rooms that have events scheduled
  --inline-css    Embed the CSS directly into the generated files instead
  --input <file>  Input filename, UTF-16 spreadsheet or xlsx file
                  May have a :# suffix to select a sheet by index
  --just-guest    Include only descriptions for guest panels
  --kiosk         Generate HTML for use in the Schedule Kiosk
  --output <file> Output filename or directory
  --postcard      Wrap description in table to force width
  --separate      Put descriptions after all grids instead of mixing them
  --split-day     Only split at SPLITDAY, not half day splits
  --style <file>  Embed CSS into generated HTML, may be given multiple times,
                  implies --inline-css
  --title <NAME>  Sets the page titles
  --unified       Do not split table by SPLIT time segments or days
```

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

The underscores below can be spaces in the spreadsheet.

Normal Columns:

* Uniq_ID - ID of panel
* Name - Panel name
* Room - Room name
* Start_Time - Starting time of panel
* Duration - HH:MM (hours and minutes)
* End_Time - Ending time of panel (only one of Duration or End_Time is required)
* Description - Description of the panel (UTF-16 text)
* Note - Notes to display in description
* Difficulty - Difficulty of the panel (1 to 5)
* Tokens - How many tokens to attend panel
* Seats_Sold - currently ignored. Number of seats sold.
* Capacity - currently ignored. Max number of seats.
* Full - IF the panel is full (TODO this is getting replaced with Seats_Sold and
  Capacity )
* Hide_Panelist - If not-blank, do not show any panelist
* Alt_Panelist - Use as panelist instead of showing the selected names

These columns are required for text file spreadsheets, otherwise a Rooms and
PanelType sheet can be used to look up the information.

* Kind - Panel kind
* Room_Idx - Id of room, used for sorting
* Real_Room - Hotel room name

Panelist Columns

The syntax for panelist columns is _Kind_:_Name_=_Group_, _Kind_:_Name_, or _Kind_:Other

The following kinds are supported

* G - Guest
* S - Staff
* I - Invited panelist
* F - Fan panelist

_Name_ is the name of the guest as shown. If the name is other, the contents of
the cell should be a list of names separated by commas.

_Group_ is the group that guest belongs to, if all members of a group are
attending they will be listed as a group instead of individually.

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

# Spliting the grid

The special SPLIT... rooms are used to control where the grid splits

Example of what splits are defined like in the main schedule.

| Uniq ID | Name               | Room       | Start Time      |
|---------|--------------------|------------|-----------------|
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

| Room Name   | Sork Key | Hotel Room | Long Name |
|-------------|----------|------------|-----------|
| SPLITDAY    | 101      | SPLIT      | SPLIT     |
| SPLITNIGHT  | 101      | SPLIT      | SPLIT     |


## PanelTypes sheet

Maping between UniqID prefix and panel types.

* Prefix - Two letter prefix of Uniq ID
* Panel Kind - Full name of the panel kind

Examples:

| Uniq ID | Name         | Room   | Start Time      | Duration | Description        | G:John Smith |
|---------|--------------|--------|-----------------|----------|--------------------|--------------|
| DE01    | How to panel | Panel1 | 6/24/2022 08:00 | 01:00    | Learn how to panel | Yes          |

| Prefix | Panel Kind |
|--------|------------|
| DE     | DEMO       |


##

Examples:

Produces a schedule that will print nicely in landscape from edge:
```
desc_tbl \
  --style license-fonts.css \
  --style landscape.css \
  --style common.css \
  --input input/Schedule.xlsx \
  --output output/ \
  --seperate --split-day
```

Produces a schedule for each room
```
desc_tbl \
  --style license-fonts.css \
  --style landscape.css \
  --style common.css \
  --input input/Schedule.xlsx \
  --output output/ \
  --file-by-day --split-day
```

## Licensing:

For desc_tbl see LICENSE

Files in .devcontainer may have their own license, SUCH as MIT
