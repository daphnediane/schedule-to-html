# schedule-to-html
Convert spreadsheet to html webpage with schedule

Utility that I use to create an HTML page from a schedule for Cosplay America.

Not very well documented sorry.

Quick start:

Convert spreadsheet to File Format: UTF-16 Unicode Text (.txt)

And place file in the input directory.

## Run:

desc_tbl --input input/spreadsheet.txt --output output/

## Options:
```
  --day           Include a column for week day
  --description   Includes panel descriptions, implies --no-grid
  --grid          Includes the grid, implies --no-description
  --guests        Create a file per guest with their panels highlighted
  --hideunused    Only include rooms that have events scheduled
  --inline_css    Embed the CSS directly into the generated files instead
  --input <file>  Input filename, UTF-16 spreadsheet
  --justguest     I believe this just includes guest panels
  --kiosk         Generate HTML for use in the Schedule Kiosk
  --output <file> Output filename or directory
  --perday        Only split at SPLITDAY, not half day splits
  --postcard      Wrap description in table to force width
  --separate      Put descriptions after all grids instead of mixing them
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

These columns are currently computed by the spreadsheet (TODO handle by the program)

* Kind - Panel kind
* Room_Idx - Id of room, used for sorting
* Real_Room - Hotel room name

## Licensing:

For desc_tbl see LICENSE

Files in .devcontainer may have their own license, SUCH as MIT
