module.exports = {
  purge: [
    '../lib/<%= @lib_web_name %>/templates/**/*.eex',<%= if @live do %>
    '../lib/<%= @lib_web_name %>/templates/**/*.leex',
    '../lib/<%= @lib_web_name %>/live/**/*.ex',
    '../lib/<%= @lib_web_name %>/live/**/*.leex',<% end %>
    '../lib/<%= @lib_web_name %>/views/**/*.ex',
    './js/**/*.js'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {}
  },
  variants: {},
  plugins: []
}
