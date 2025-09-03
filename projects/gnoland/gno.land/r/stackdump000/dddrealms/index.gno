package dddrealms

import (
    "net/url"
)

func Render(path string) string {
    return RenderMarkdown(path)
}

func RenderMarkdown(path string) string {
    return "![3d voxels](" + RenderSvg(path) + ")\n"
}

func RenderSvg(path string) string {
    return "data:image/svg+xml;utf8," + url.PathEscape(Drealm)
}

var Drealm = `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600" role="img">
  <title>Minecraft Voxels (CSS 3D in SVG)</title>
  <desc>
    A small stack of voxels rendered in 3D using CSS transforms within a
    foreignObject. Spins slowly to showcase depth. No external assets.
  </desc>

  <!-- Soft background -->
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#aee2ff"/>
      <stop offset="100%" stop-color="#e9f6ff"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="100%" height="100%" fill="url(#sky)"/>

  <switch>
    <!-- Preferred path: XHTML via foreignObject -->
    <foreignObject x="0" y="0" width="100%" height="100%" requiredExtensions="http://www.w3.org/1999/xhtml">
      <div xmlns="http://www.w3.org/1999/xhtml" style="width:100%;height:100%;">
        <style>
          :root {
            --u: 36px;              /* cube edge size */
            --h: calc(var(--u)/2);  /* half edge */
            --nx: 4;                /* grid size X */
            --ny: 4;                /* grid size Y (height) */
            --nz: 4;                /* grid size Z */
            --cx: calc((var(--nx) - 1) / 2); /* center offsets */
            --cy: calc((var(--ny) - 1) / 2);
            --cz: calc((var(--nz) - 1) / 2);
          }
          .viewport { width:100%; height:100%; display:flex; align-items:center; justify-content:center; }
          .stage { position:relative; width: calc(8 * var(--u)); height: calc(6 * var(--u)); perspective: 1200px; }
          .scene { position:absolute; inset:0; margin:auto; width: calc(4 * var(--u)); height: calc(4 * var(--u)); transform-style: preserve-3d; transform: rotateX(30deg) rotateY(35deg) translateZ(0); animation: spin 16s linear infinite; }
          @keyframes spin { from { transform: rotateX(30deg) rotateY(0deg); } to { transform: rotateX(30deg) rotateY(360deg); } }

          .voxel { position:absolute; top:50%; left:50%; width: var(--u); height: var(--u); transform-style: preserve-3d; 
                   transform: translate3d(calc((var(--x) - var(--cx)) * var(--u)),
                                            calc((var(--cy) - var(--y)) * var(--u)),
                                            calc((var(--z) - var(--cz)) * var(--u)));
          }
          .face { position:absolute; width:100%; height:100%; border: 1px solid rgba(0,0,0,0.08); box-sizing: border-box; opacity: 0.98; }
          .front { transform: translateZ(var(--h)); }
          .back  { transform: rotateY(180deg) translateZ(var(--h)); }
          .right { transform: rotateY(90deg)  translateZ(var(--h)); }
          .left  { transform: rotateY(-90deg) translateZ(var(--h)); }
          .top   { transform: rotateX(90deg)  translateZ(var(--h)); }
          .bottom{ transform: rotateX(-90deg) translateZ(var(--h)); }

          /* Materials */
          /* Stone */
          .mat-stone .top    { background: #a6adb7; }
          .mat-stone .side   { background: #8b95a1; }
          .mat-stone .bottom { background: #6f7781; }

          /* Dirt */
          .mat-dirt .top    { background: #9b6a3e; }
          .mat-dirt .side   { background: #805231; }
          .mat-dirt .bottom { background: #694427; }

          /* Grass (dirt sides + green top) */
          .mat-grass .top    { background: #5fbe3a; }
          .mat-grass .side   { background: #7a5a32; }
          .mat-grass .bottom { background: #694427; }

          /* A touch of shading for better depth */
          .front, .right { filter: brightness(0.98); }
          .left { filter: brightness(0.92); }
          .back { filter: brightness(0.88); }
          .bottom { filter: brightness(0.75); }

          /* Label */
          .label { position:absolute; left:0; right:0; bottom:6px; text-align:center; color:#2e3a44; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; font-size: 14px; opacity: 0.8; }
        </style>
        <div class="viewport">
          <div class="stage">
            <div class="scene" aria-label="Voxel scene">
              <!-- Layer y=0 : 4x4 base -->
              <!-- stone base under dirt/grass to hint depth -->
              <div class="voxel mat-stone" style="--x:0;--y:0;--z:0;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:1;--y:0;--z:0;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:2;--y:0;--z:0;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:3;--y:0;--z:0;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <div class="voxel mat-stone" style="--x:0;--y:0;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:1;--y:0;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:2;--y:0;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:3;--y:0;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <div class="voxel mat-stone" style="--x:0;--y:0;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:1;--y:0;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:2;--y:0;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:3;--y:0;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <div class="voxel mat-stone" style="--x:0;--y:0;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:1;--y:0;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:2;--y:0;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-stone" style="--x:3;--y:0;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <!-- Layer y=1 : 3x3 inline hill (dirt with grass top above) -->
              <div class="voxel mat-dirt"  style="--x:1;--y:1;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:2;--y:1;--z:1;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:1;--y:1;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:2;--y:1;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:1;--y:1;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-dirt"  style="--x:2;--y:1;--z:3;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <!-- Layer y=2 : 2x2 -->
              <div class="voxel mat-grass" style="--x:1;--y:2;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>
              <div class="voxel mat-grass" style="--x:2;--y:2;--z:2;"><div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div></div>

              <!-- Layer y=3 : 1 top voxel -->
              <div class="voxel mat-grass" style="--x:1.5;--y:3;--z:2;">
                <div class="face front side"></div><div class="face back side"></div><div class="face right side"></div><div class="face left side"></div><div class="face top"></div><div class="face bottom"></div>
              </div>
            </div>
            <!--<div class="label">SVG &lt;foreignObject&gt; voxels — CSS 3D, no JS</div> -->
          </div>
        </div>
      </div>
    </foreignObject>
  </switch>
</svg>
`
