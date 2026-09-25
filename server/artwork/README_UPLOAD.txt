HuePop artwork manifest
=======================

Upload artworks.json to:
/public_html/huepop/artwork/artworks.json

Public URL:
https://bigupstar.com/huepop/artwork/artworks.json

The image_url field may be either:
1. a filename/relative URL such as "car.png" (recommended when the PNG sits beside artworks.json), or
2. a full https:// URL.

Required fields used by the app:
- id
- title
- category
- premium (true/false)
- image_url
- age_group (Kids, Teens, Adults)
- progress_id
- sort_order

Optional:
- new (true/false)

You can add, remove, reorder, or change premium/category/age settings in this JSON without rebuilding the app.
Keep id and progress_id stable after users have begun coloring an artwork so saved progress continues to match.
