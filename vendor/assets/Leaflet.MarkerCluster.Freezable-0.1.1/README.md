# Leaflet.MarkerCluster.Freezable
Sub-plugin for [Leaflet.markercluster](https://github.com/Leaflet/Leaflet.markercluster)
plugin (MCG in short); adds the ability to freeze clusters at a specified zoom.

[Leaflet.markercluster](https://github.com/Leaflet/Leaflet.markercluster) plugin
provides beautiful animated Marker Clustering functionality.

[Leaflet](http://leafletjs.com/) is the leading open-source JavaScript library
for mobile-friendly interactive maps.

[![GitHub releases](https://img.shields.io/github/release/ghybs/leaflet.markercluster.freezable.svg?label=GitHub)](https://github.com/ghybs/Leaflet.MarkerCluster.Freezable/releases)
[![npm](https://img.shields.io/npm/v/leaflet.markercluster.freezable.svg)](https://www.npmjs.com/package/leaflet.markercluster.freezable)



## Requirements
This plugin should be compatible with both combinations:
- Leaflet 1.0.x + Leaflet.markercluster 1.0.0
- Leaflet legacy (0.7.x) + Leaflet.markercluster legacy (0.5.x)



## Demos
- [Leaflet.MarkerCluster.Freezable (Leaflet 1.0.1 + Leaflet.markercluster 1.0.0)](http://ghybs.github.io/Leaflet.MarkerCluster.Freezable/examples/mcg-freezable-leaflet1.0.0.html)
- [Leaflet.MarkerCluster.Freezable (Leaflet 0.7.7 + Leaflet.markercluster 0.5.0)](http://ghybs.github.io/Leaflet.MarkerCluster.Freezable/examples/mcg-freezable.html)


## Usage instructions

### Quick Guide
**HTML:**
```html
<!-- After Leaflet and Leaflet.markercluster scripts -->
<script src="leaflet.markercluster.freezable.js"></script>
```

**JavaScript:**
```javascript
var map = L.map("map"),
    mcg = L.markerClusterGroup(options);
    
mcg.addLayers(arrayOfMarkers);
mcg.addTo(map);

mcg.freezeAtZoom(15);
mcg.freezeAtZoom("maxKeepSpiderfy");
mcg.freezeAtZoom("max");
mcg.unfreeze(); // shortcut for mcg.freezeAtZoom(false)

mcg.disableClusteringKeepSpiderfy(); // shortcut for mcg.freezeAtZoom("maxKeepSpiderfy")
mcg.disableClustering(); // shortcut for mcg.freezeAtZoom("max")
mcg.enableClustering(); // alias for mcg.unfreeze()
```

When frozen / disabled, clusters will no longer split / merge on map zoom, but
retain their status as if they were on the specified zoom level. They will
directly spiderfy when clicked on, instead of zooming to bounds (since zooming
will not make them split apart).

In particular, freezing at `maxZoom + 1` removes all clusters.

Freezing at `maxZoom` removes all clusters except the bottom-most ones, so that
user can still spiderfy closely positioned markers.

**CAUTION: make sure your operations makes sense before freezing to high zoom
whereas the map is at a low zoom. It may have to load _thousands_ of markers
suddenly!**

_Note: while frozen, MCG will continue removing clusters and markers which are
far from the view port, accordingly with `removeOutsideVisibleBounds` option._



### Installing the sub-plugin

#### Local copy
1. Download the "<a href="https://github.com/ghybs/Leaflet.MarkerCluster.Freezable/releases/download/v0.1.1/leaflet.markercluster.freezable.js">`leaflet.markercluster.freezable.js`</a>" file from the [`v0.1.1` release](https://github.com/ghybs/Leaflet.MarkerCluster.Freezable/releases/tag/v0.1.1).
2. Place the file alongside your page.
3. Add the `script` tag (see [Quick Guide > HTML](#quick-guide)) to your page after Leaflet and Leaflet.markercluster scripts.

#### CDN
You can alternatively use the free [unpkg](https://unpkg.com) CDN service, but keep in mind that it "[_is a free, best-effort service and cannot provide any uptime or support guarantees_](https://unpkg.com/#/about)".

```html
<!-- After Leaflet script -->
<script src="https://unpkg.com/leaflet.markercluster.freezable@0.1.1/dist/leaflet.markercluster.freezable.js"></script>
```



### Creation
Simply use the the regular `L.markerClusterGroup` factory, as Freezable plugin
directly adds new methods to Leaflet.markercluster:

```javascript
var mcg = L.markerClusterGroup(options);

mcg.addTo(map);
```



## API Reference

### Methods
| Method  | Returns  | Description |
| :------ | :------- | :---------- |
| **freezeAtZoom**( `<Number>` or `<String>` or `<Boolean>` frozenZoom? ) | `this` | Freezes clusters at specified zoom, current zoom, or unfreeze. If passed a positive number (including 0), freezes at that zoom. If passed `"max"` (string), freezes at `maxZoom + 1`. If passed `"maxKeepSpiderfy"` (string), freezes at `maxZoom`. If passed nothing, `undefined`, `true` (boolean) or `NaN`, freezes at current zoom. If passed `false` (boolean) or any other non-number, unfreezes. |
| **unfreeze**() | `this` | Shortcut for `freezeAtZoom(false)`. |
| **disableClustering**() | `this` | Shortcut for `freezeAtZoom("max")`. |
| **disableClusteringKeepSpiderfy**() | `this` | Shortcut for `freezeAtZoom("maxKeepSpiderfy")`. |
| **enableClustering**() | `this` | Shortcut for `unfreeze()`. |

MCG.Freezable does not provide any extra option or event.


### Regular MCG options, events and methods
All regular MCG [options](https://github.com/Leaflet/Leaflet.markercluster#all-options),
[events](https://github.com/Leaflet/Leaflet.markercluster#events) and
[methods](https://github.com/Leaflet/Leaflet.markercluster#methods) are
available within MCG Layer Support. Refer to Leaflet.markercluster documentation.



## Limitations

### Freezing at current zoom while not on map
If you request MCG to freeze at current zoom, but MCG is not on any map at that
moment, it will freeze at the zoom the map is at when added to it.

## License
[![license](https://img.shields.io/github/license/ghybs/leaflet.markercluster.freezable.svg)](LICENSE)

Leaflet.MarkerCluster.Freezable is distributed under the
[MIT License](http://choosealicense.com/licenses/mit/) (Expat type), like
Leaflet.markercluster.
