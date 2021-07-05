defmodule BanchanWeb.StudioNewLive do
  @moduledoc """
  New studio creation page.
  """
  use BanchanWeb, :surface_view

  import Slug
  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, Label, Submit, TextArea, TextInput}

  alias Banchan.Studios
  alias Banchan.Studios.Studio
  alias BanchanWeb.Endpoint

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    changeset = Studio.changeset(%Studio{}, %{})
    {:ok, assign(socket, changeset: changeset)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <h1>New Studio</h1>

    <Form for={@changeset} change="change" submit="submit" opts={autocomplete: "off"}>
      <Field name={:name}>
        <Label />
        <TextInput />
        <ErrorTag />
      </Field>
      <Field name={:slug}>
        <Label />
        <TextInput />
        <ErrorTag />
      </Field>
      <Field name={:description}>
        <Label />
        <TextArea rows="3" />
        <ErrorTag />
      </Field>
      <Submit label="Save" opts={disabled: Enum.empty?(@changeset.changes) || !@changeset.valid?}/>
    </Form>
    """
  end

  @impl true
  def handle_event("change", %{"studio" => studio, "_target" => target}, socket) do
    studio =
      if target == ["studio", "name"] do
        %{studio | "slug" => slugify(studio["name"])}
      else
        studio
      end

    changeset =
      %Studio{}
      |> Studio.changeset(studio)
      |> Map.put(:action, :update)

    socket = assign(socket, changeset: changeset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", val, socket) do
    case Studios.new_studio(%Studio{user: socket.assigns.current_user}, val["studio"]) do
      {:ok, studio} ->
        put_flash(socket, :info, "Profile updated")
        # TODO(zkat): Make this redirect to view_path instead once that exists.
        {:noreply, redirect(socket, to: Routes.studio_edit_path(Endpoint, :edit, studio.slug))}

      other ->
        other
    end
  end
end