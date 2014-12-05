defmodule <%= application_module %>.<%= controller_name %> do
  use Phoenix.Controller

  plug :action

  # GET /<%= controller %>
  def index(conn, _params) do
  end
  
  # GET /<%= controller %>/:id/edit
  def edit(conn, _params) do
  end

  # POST /<%= controller %>/new
  def new(conn, _params) do
  end

  # GET /<%= controller %>/:id
  def show(conn, _params) do
  end

  # POST /<%= controller %>
  def create(conn, _params) do
  end

  # PUT /<%= controller %>/:id
  def update(conn, _params) do
  end

  # DELETE /<%= controller %>/:id
  def destroy(conn, _params) do
  end
end
