defmodule BanchanWeb.CommissionLive.Components.Comment do
  @moduledoc """
  Component for commission page comments
  """
  use BanchanWeb, :live_component

  alias Banchan.Commissions
  alias Banchan.Repo

  alias Surface.Components.Form

  alias BanchanWeb.Components.{Avatar, Button, Markdown, UserHandle}
  alias BanchanWeb.Components.Form.{MarkdownInput, Submit}
  alias BanchanWeb.CommissionLive.Components.{AttachmentBox, InvoiceBox}

  prop actor, :struct, required: true
  prop current_user, :struct, required: true
  prop current_user_member?, :boolean, required: true
  prop commission, :struct, required: true
  prop event, :struct, required: true
  prop uri, :string, required: true

  data changeset, :struct

  defp fmt_time(time) do
    Timex.format!(time, "{relative}", :relative)
  end

  defp fmt_abs_time(time) do
    time |> Timex.to_datetime() |> Timex.format!("{RFC822}")
  end

  @impl true
  def update(params, socket) do
    socket = socket |> assign(params) |> assign(changeset: nil)
    socket = socket |> assign(event: socket.assigns.event)
    {:ok, socket}
  end

  @impl true
  def handle_event("edit", %{}, socket) do
    assigns = socket.assigns

    {:noreply,
     socket
     |> assign(
       changeset:
         (assigns.current_user_member? || assigns.current_user.id == assigns.actor.id) &&
           Commissions.change_event_text(assigns.event, %{})
     )}
  end

  @impl true
  def handle_event("change_edit", %{"event" => event}, socket) do
    changeset =
      socket.assigns.event
      |> Commissions.change_event_text(event)
      |> Map.put(:action, :update)

    socket = assign(socket, changeset: changeset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_edit", %{"event" => event}, socket) do
    case Commissions.update_event(socket.assigns.current_user, socket.assigns.event, event) do
      {:ok, event} ->
        {:noreply,
         socket
         |> assign(
           event: event |> Repo.preload([:attachments, :actor, :invoice]),
           changeset: nil
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(changeset: changeset)}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, socket |> assign(changeset: nil)}
  end

  @impl true
  def handle_event("remove_attachment", %{"attachment-idx" => idx}, socket) do
    {index, ""} = Integer.parse(idx)
    attachment = Enum.fetch!(socket.assigns.event.attachments, index)

    Commissions.delete_attachment!(
      socket.assigns.current_user,
      socket.assigns.commission,
      socket.assigns.event,
      attachment
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_history", _, socket) do
    {:noreply,
     socket |> assign(event: socket.assigns.event |> Repo.preload(history: [:changed_by]))}
  end

  defp replace_fragment(uri, event) do
    URI.to_string(%{URI.parse(uri) | fragment: "event-#{event.public_id}"})
  end

  def render(assigns) do
    ~F"""
    <div class="shadow-md bg-base-200 rounded-box pb-4">
      <div class="flex flex-row text-sm pt-2 px-2 -mb-4">
        <div class="inline-flex grow items-center flex-wrap space-x-1">
          <Avatar class="w-6" user={@actor} />
          <UserHandle user={@actor} />
          <span>
            {#if @event.invoice}
              posted an invoice
            {#else}
              commented
            {/if}
            <a
              title={"#{fmt_abs_time(@event.inserted_at)}"}
              class="hover:underline"
              href={replace_fragment(@uri, @event)}
            >{fmt_time(@event.inserted_at)}</a>.
          </span>
          {#if @event.inserted_at != @event.updated_at}
            <div class="dropdown">
              <label :on-click="load_history" tabindex="0" class="text-xs italic hover:link">
                edited {fmt_time(@event.updated_at)}
              </label>
              <ol tabindex="0" class="dropdown-content menu p-2 shadow bg-base-100 rounded-box">
                {#if Ecto.assoc_loaded?(@event.history)}
                  {#for history <- @event.history}
                    <li class="block">
                      <div class="flex flex-col place-items-start">
                        <div>
                          Comment from {fmt_time(history.written_at)} changed by <UserHandle user={history.changed_by} />
                        </div>
                        {#if :mod in @current_user.roles || :admin in @current_user.roles}
                          <div class="font-bold">
                            Original Text:
                          </div>
                          <div>
                            <Markdown content={history.text} />
                          </div>
                        {/if}
                      </div>
                    </li>
                  {/for}
                {/if}
              </ol>
            </div>
          {/if}
        </div>
        {#if !@changeset && (@current_user_member? || @current_user.id == @actor.id)}
          <button type="button" :on-click="edit" class="ml-auto hover:underline"><i class="fas fa-edit" /></button>
        {/if}
      </div>

      <div class="divider" />

      <div class="content px-4 user-markdown">
        {#if @changeset}
          <Form
            for={@changeset}
            change="change_edit"
            submit="submit_edit"
            opts={id: "editing-event-#{@event.public_id}"}
          >
            <MarkdownInput
              id={"editing-event-#{@event.public_id}"}
              name={:text}
              show_label={false}
              class="w-full"
            />
            <div class="flex flex-row-reverse">
              <Submit class="inline" label="Update" />
              <Button class="inline btn-error" click="cancel_edit">Cancel</Button>
            </div>
          </Form>
        {#else}
          <Markdown content={@event.text} />
        {/if}
      </div>

      {#if @event.invoice}
        <div :if={@event.text} class="divider" />
        <div class="pb-4">
          <InvoiceBox
            id={"invoice-box-#{@event.public_id}"}
            current_user={@current_user}
            current_user_member?={@current_user_member?}
            uri={@uri}
            commission={@commission}
            event={@event}
          />
        </div>
      {/if}

      {#if Enum.any?(@event.attachments)}
        <div :if={@event.text} class="divider" />
        <div class="px-4">
          <AttachmentBox
            base_id={@id <> "-attachments"}
            editing={!is_nil(@changeset)}
            commission={@commission}
            attachments={@event.attachments}
            open_preview="open_preview"
            remove_attachment="remove_attachment"
            pending_payment={@event.invoice && @event.invoice.required && !Commissions.invoice_paid?(@event.invoice)}
            current_user_member?={@current_user_member?}
          />
        </div>
      {/if}
    </div>
    """
  end
end
