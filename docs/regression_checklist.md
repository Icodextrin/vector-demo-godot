# Regression Checklist

Use this checklist after renderer or entity pipeline changes.

## 1) Style Fallback

1. Open `res://scenes/main.tscn`.
2. Clear `BouncingBall.vector_style`.
3. Keep `VectorRenderer.default_style` assigned.
4. Run scene and confirm the ball still renders.

Pass condition: command fallback uses renderer default style without dropping geometry.

## 2) Trail Lifecycle

1. Open `res://scenes/main.tscn`.
2. Verify moving geometry creates trails.
3. Increase `VectorRendererPreset.decay_alpha` to around `0.2`.
4. Re-run and confirm trails fade out quickly.
5. Set `trail_enabled = false` on `BouncingBall`.
6. Re-run and confirm only the current frame is visible.

Pass condition: ingest, decay, and dead-sample cleanup remain stable.

## 3) Layer Ordering

1. Open `res://scenes/player_ship_walls_demo.tscn`.
2. Set `PlayerShipVisual.draw_layer = 10`.
3. Set a wall visual `draw_layer = 0`.
4. Run and confirm ship draws over wall geometry.
5. Swap values and confirm ordering reverses.

Pass condition: lower layers render first and higher layers render last.

## 4) Parameter Guards

1. Set `BouncingBall.circle_segments = 3` and run.
2. Set `BouncingBall.circle_segments = 256` and run.
3. Verify no divide-by-zero or script errors.
4. Set `StaticVectorEntity.rect_size` to very small values (for example `0.1, 0.1`) and run.

Pass condition: guard rails prevent invalid geometry and runtime errors.
