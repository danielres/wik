defmodule Wik.Events.Event do
  use Ash.Resource,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "app_events"
    repo Wik.Repo
  end

  event_log do
    # Module that implements clear_records! callback
    clear_records_for_replay Wik.Events.ClearAllRecords

    # Optional. Defaults to :integer, Ash.Type.UUIDv7 is the recommended option
    # if your event log is set up with multitenancy via the attribute-strategy.
    primary_key_type Ash.Type.UUIDv7

    # Optional, defaults to :uuid
    record_id_type :uuid

    # Store primary key of actors running the actions
    persist_actor_primary_key :user_id, Wik.Accounts.User
    # persist_actor_primary_key :system_actor, Wik.SystemActor, attribute_type: :string

    # Optional: Control field visibility for public interfaces
    # or [:id, :resource, :action, :occurred_at], or [] (default)
    public_fields :all
  end

  actions do
    defaults [:read]
  end

  # Optional: Configure replay overrides for version handling
  # replay_overrides do
  #   replay_override Wik.Accounts.User, :create do
  #     versions [1]
  #     route_to Wik.Accounts.User, :old_create_v1
  #   end
  # end
end
