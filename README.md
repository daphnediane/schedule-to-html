# schedule-to-html
Convert spreadsheet to html webpage with schedule

Utility that I use to create an HTML page from a schedule for Cosplay America.

Not very well documented sorry.

Quick start:

Convert spreadsheet to File Format: UTF-16 Unicode Text (.txt)

And place file in the input directory.

Run:
desc_tbl --input input/spreadsheet.txt --output output/

Options:
  --input <file>  Input filename, UTF-16 spreadsheet
  --output <file> Output filename or directory
  --day           Include a column for week day
  --unified       Do not split table by SPLIT time segments or days
  --perday        Only split at SPLITDAY, not half day splits
  --separate      Put descriptions after all grids instead of mixing them
  --style <file>  Embed CSS into generated HTML, may be given multiple times,
                  implies --inline-css
  --inline_css    Embed the CSS directly into the generated files instead
  --guests        Create a file per guest with their panels highlighted
  --postcard      Wrap description in table to force width
  --justguest     I believe this just includes guest panels
  --hideunused    Only include rooms that have events scheduled
  --grid          Includes the grid, implies --no-description
  --description   Includes panel descriptions, implies --no-grid
  --kiosk         Generate HTML for use in the Schedule Kiosk
  --title <NAME>  Sets the page titles

Licensing:
For desc_tbl see LICENSE
Files in .devcontainer may have their own license, SUCH as MIT
