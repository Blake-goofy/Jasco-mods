# Wiki Pages

This directory contains the wiki pages for the Jasco-mods repository, generated from all README.md files in the repository.

## How to publish these pages to the GitHub wiki:

1. First, enable the wiki for the repository in GitHub (Settings > Features > Wikis)
2. Clone the wiki repository:
   ```bash
   git clone https://github.com/Blake-goofy/Jasco-mods.wiki.git
   ```
3. Copy all .md files from this `wiki/` directory to the cloned wiki repository
4. Commit and push to the wiki:
   ```bash
   cd Jasco-mods.wiki
   git add .
   git commit -m "Add wiki pages from README files"
   git push
   ```

## Wiki Pages Structure:

- **Home.md** - Main landing page (from repository root README.md)
- **JP1-Custom-Views-Update.md** - JP1 customization documentation (from JP1/JP1-README.md)
- **JP2-Case-Label-Customers-ODWS-Mod.md** - JP2 customization documentation (from JP2/JP2-README.md)

All images are referenced using raw.githubusercontent.com URLs so they display correctly in the wiki.
