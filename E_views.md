## Views

The Phoenix view layer is composed of two main components. There is the application view, which serves as the base for all the other views. This is where application-wide view behavior goes. There is also a directory of user defined views, each of which acts as a link between a specific controller and it's related templates.

Views have two main jobs to perform, to render templates - including layouts - and to provide functions for transforming raw data into something templates can easily consume.

### Main Application View
- `/web/views.ex`
- the `__using__` macro
  - global imports, aliases and the like for all views to share
  - global functions for all views to share
- rendering
  - to string
  - render_within
  - render_layout
  - html safety
  - examples on iex

### Individual Views
- `/web/views/my_view.ex`
- if you come from oop, you might want to think of these as instances of the application view. resist!
  - they include the functions, imports, aliases and such from the application view.
- naming conventions
- purpose in life
  - act as decorators
  - helper functions useful for only one controller/templates group
