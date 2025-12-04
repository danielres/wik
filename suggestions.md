# Remaining Realtime Simplification Suggestions

## Priority 1: High Impact, Medium Effort

### 1. Create Generic Subscription Helper

**Problem:** All LiveViews have nearly identical subscription logic in `mount/3`

```elixir
if connected?(socket) do
  Phoenix.PubSub.subscribe(Wik.PubSub, "group:created")
  Phoenix.PubSub.subscribe(Wik.PubSub, "group:updated") 
  Phoenix.PubSub.subscribe(Wik.PubSub, "group:destroyed")
end
```

**Solution:** Create `RealtimeSubscriptions.subscribe_for_resource(socket, :group, id)`

- Auto-subscribes to both specific (`group:updated:123`) and collection (`group:updated`) topics
- Based on what's in socket assigns
- Would eliminate 3-5 lines of boilerplate per LiveView

### 2. Convert Streams to Assigns

**Problem:** Index pages use streams but collections are small
**Benefit:** Simpler code, easier to reason about

- Convert `group_live/index.ex` and `home_live.ex` from streams to regular list assigns
- Eliminate stream-specific logic in templates
- Simpler update patterns

### 3. Consolidate Reload Functions  

**Problem:** `reload_group!`, `reload_page!` functions are nearly identical

```elixir
defp reload_group!(slug, socket) do
  Wik.Accounts.Group |> Ash.get!(...)
end

defp reload_page!(page_slug, socket) do  
  Wik.Wiki.Page |> Ash.get!(...)
end
```

**Solution:** `RealtimeReloaders.reload_resource(Wik.Accounts.Group, id, socket)`

- Generic reload logic
- Consistent load options handling

## Priority 2: Medium Impact, Low Effort

### 4. Standardize Visual Feedback Helpers

**Problem:** Repetitive highlight/animation clearing logic

```elixir
Process.send_after(self(), :clear_updated_fields, 2000)
# ... later
def handle_info(:clear_updated_fields, socket) do
  {:noreply, assign(socket, :updated_fields, [])}
end
```

**Solution:** `RealtimeVisuals.handle_update_feedback(socket, updated_fields)`

- Consolidate `Process.send_after` and field clearing patterns
- Consistent timing and behavior

### 5. Generic Clear Handlers

**Problem:** Similar handlers in all files

- `:clear_updated_fields`
- `{:clear_highlight, id}`

**Solution:** Shared handlers or behavior

## Priority 3: High Impact, High Effort

### 6. Create RealtimeHandlers Behavior

**Problem:** Repetitive broadcast handler boilerplate
**Solution:** Similar to `WikWeb.Presence.Handlers`

```elixir
use WikWeb.RealtimeHandlers, resource: :group, collection: true
```

- Generate appropriate `handle_info/2` functions based on resource type
- Could eliminate 80% of broadcast handler boilerplate
- Most complex but highest payoff

### 7. Generic Redirect Logic

**Problem:** Hardcoded redirect patterns for deletions
**Solution:** Extract into configurable system

- Auto-detect resource type and redirect appropriately
- Consistent navigation patterns

## Priority 4: Nice to Have

### 8. Unified Event Handling

**Solution:** `handle_resource_broadcast(event, payload, socket, opts)`

- Generic handler that dispatches to update/create/destroy logic
- Reduce duplication in broadcast handlers

### 9. Configuration-Driven Subscriptions

**Solution:** Define subscription patterns in config

- Auto-subscribe based on assigns
- Declarative approach to realtime subscriptions

## Implementation Order Recommendation

1. **Subscription Helper** - Quick win, immediate code reduction
2. **Streams → Assigns** - Good foundation for other simplifications  
3. **Reload Functions** - Easy consolidation
4. **Visual Feedback Helpers** - Polish and consistency
5. **RealtimeHandlers Behavior** - Big refactor, save for when ready

## Notes

- Each suggestion preserves existing functionality
- Focus on eliminating repetition while maintaining clarity
- All changes should be backward compatible during transition

