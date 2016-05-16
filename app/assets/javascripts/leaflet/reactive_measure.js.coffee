L.Polygon.include
  ###
  # Get centroid of the polygon in square meters
  # Portage from leaflet1.0.0-rc1: https://github.com/Leaflet/Leaflet/blob/master/src/layer/vector/Polygon.js
  # @return {number} polygon centroid
   ###
  __getCenter: ->
    @__project()
    points = @_rings[0]
    len = points.length
    if !len
      return null
    # polygon centroid algorithm; only uses the first ring if there are multiple
    area = x = y = 0
    i = 0
    j = len - 1
    while i < len
      p1 = points[i]
      p2 = points[j]
      f = p1.y * p2.x - (p2.y * p1.x)
      x += (p1.x + p2.x) * f
      y += (p1.y + p2.y) * f
      area += f * 3
      j = i++
    if area == 0
      # Polygon is so small that all points are on same pixel.
      center = points[0]
    else
      center = [
        x / area
        y / area
      ]
    @_map.layerPointToLatLng center

L.Polyline.include
  ###
  # Return LatLngs as array of [lat, lng] pair.
  # @return {Array} [[lat,lng], [lat,lng]]
   ###
  getLatLngsAsArray: ->
    arr = []
    for latlng in @_latlngs
      arr.push [latlng.lat, latlng.lng]
    arr

  ###
  # Get center of the polyline in meters
  # Portage from leaflet1.0.0-rc1: https://github.com/Leaflet/Leaflet/blob/master/src/layer/vector/Polyline.js
  # @return {number} polyline center
   ###
  __getCenter: ->
    @__project()
    i = undefined
    halfDist = undefined
    segDist = undefined
    dist = undefined
    p1 = undefined
    p2 = undefined
    ratio = undefined
    points = @_rings[0]
    len = points.length
    if !len
      return null
    # polyline centroid algorithm; only uses the first ring if there are multiple
    i = 0
    halfDist = 0
    while i < len - 1
      halfDist += points[i].distanceTo(points[i + 1]) / 2
      i++
    # The line is so small in the current view that all points are on the same pixel.
    if halfDist == 0
      return @_map.layerPointToLatLng(points[0])
    i = 0
    dist = 0
    while i < len - 1
      p1 = points[i]
      p2 = points[i + 1]
      segDist = p1.distanceTo(p2)
      dist += segDist
      if dist > halfDist
        ratio = (dist - halfDist) / segDist
        return @_map.layerPointToLatLng([
          p2.x - (ratio * (p2.x - (p1.x)))
          p2.y - (ratio * (p2.y - (p1.y)))
        ])
      i++
    return

  __project: ->
    pxBounds = new (L.Bounds)
    @_rings = []
    @__projectLatlngs @_latlngs, @_rings, pxBounds
    return

  # recursively turns latlngs into a set of rings with projected coordinates
  __projectLatlngs: (latlngs, result, projectedBounds) ->
    flat = latlngs[0] instanceof L.LatLng
    len = latlngs.length
    i = undefined
    ring = undefined
    if flat
      ring = []
      i = 0
      while i < len
        ring[i] = @_map.latLngToLayerPoint(latlngs[i])
        projectedBounds.extend ring[i]
        i++
      result.push ring
    else
      i = 0
      while i < len
        @__projectLatlngs latlngs[i], result, projectedBounds
        i++
    return

L.Draw.Polyline.include
  __addHooks: L.Draw.Polyline.prototype.addHooks
  __removeHooks: L.Draw.Polyline.prototype.removeHooks
  __vertexChanged: L.Draw.Polyline.prototype._vertexChanged

  _vertexChanged: () ->
    @__vertexChanged.apply this, arguments
    @_tooltip.hide()


  __onMouseMove: (e) ->
    @_tooltip.hide()
    return unless @_markers.length > 0
    newPos = @_map.mouseEventToLayerPoint(e.originalEvent)
    mouseLatLng = @_map.layerPointToLatLng(newPos)

    latLngArray = []
    for latLng in @_poly.getLatLngs()
      latLngArray.push latLng
    latLngArray.push mouseLatLng

    # draw a polyline
    if @_markers.length == 1
      clone = L.polyline latLngArray

    # draw a polygon
    if @_markers.length >= 2
      clone = L.polygon latLngArray

    clone._map = @_map
    center = clone.__getCenter()

    g = new L.GeographicUtil.Polygon clone.getLatLngsAsArray()

    measure =
      perimeter: g.perimeter()
      area: g.area()

    @_tooltip.__updateTooltipMeasure center, measure, @options


  addHooks: () ->
    @__addHooks.apply this, arguments
    if L.DrawToolbar.reactiveMeasure
      @_tooltip = new L.Tooltip @_map, onTop: true
      @_map.on 'mousemove', @__onMouseMove, this
    return

  removeHooks: () ->
    if L.DrawToolbar.reactiveMeasure
      @_map.off 'mousemove'
    @__removeHooks.apply this, arguments
    return

L.Edit.Poly.include
  __addHooks: L.Edit.Poly.prototype.addHooks
  __removeHooks: L.Edit.Poly.prototype.removeHooks

  __onHandlerDrag: (e) ->
    center = @_poly.__getCenter()

    g = new L.GeographicUtil.Polygon @_poly.getLatLngsAsArray()

    measure =
      perimeter: g.perimeter()
      area: g.area()


    L.extend(L.Draw.Polyline.prototype.options, target: e.marker.getLatLng())

    @__tooltipMeasure.__updateTooltipMeasure center, measure, L.Draw.Polyline.prototype.options


  addHooks: () ->
    @__addHooks.apply this, arguments
    if L.EditToolbar.reactiveMeasure
      @__tooltipMeasure = new L.Tooltip @_poly._map, onTop: true
      this._poly.on 'editdrag', @__onHandlerDrag, this

  removeHooks: () ->
    if L.EditToolbar.reactiveMeasure
      this._poly.off 'editdrag'
      @__tooltipMeasure.dispose()

    @__removeHooks.apply this, arguments

L.Edit.PolyVerticesEdit.include
  __onTouchMove: L.Edit.PolyVerticesEdit::_onTouchMove

  _onMarkerDrag: (e) ->
    marker = e.target
    L.extend marker._origLatLng, marker._latlng
    if marker._middleLeft
      marker._middleLeft.setLatLng @_getMiddleLatLng(marker._prev, marker)
    if marker._middleRight
      marker._middleRight.setLatLng @_getMiddleLatLng(marker, marker._next)
    @_poly.redraw()
    # Overrides to track mouse position
    @_poly.fire 'editdrag', marker: e.target
    return

  _onTouchMove: (e) ->
    @__onTouchMove.apply @, arguments
    @_poly.fire 'editdrag'


L.LatLng.prototype.toArray = ->
  [@lat, @lng]

L.Tooltip.include
  __initialize: L.Tooltip.prototype.initialize
  __dispose: L.Tooltip.prototype.dispose

  initialize: (map,options = {}) ->
    @__initialize.apply this, arguments

    if options.onTop
      L.DomUtil.addClass(@_container, 'leaflet-draw-tooltip-top')
      L.DomEvent.on @_container, 'mouseenter', @__onMouseEnter, this
      L.DomEvent.on @_container, 'mouseleave', @__onMouseLeave, this

  dispose: ->
    @_map.off 'mouseover'
    L.DomEvent.off @_container, 'mouseenter', @__onMouseEnter, this
    L.DomEvent.off @_container, 'mouseleave', @__onMouseLeave, this
    @__dispose.apply this, arguments

  __onMouseEnter: ->
    L.DomUtil.removeClass(@_container, 'leaflet-draw-tooltip-top')


  __onMouseLeave: ->
    L.DomUtil.addClass(@_container, 'leaflet-draw-tooltip-top')

  __updateTooltipMeasure: (latLng, measure = {}, options = {}) ->
    labelText =
      text: ''
    #TODO: use L.drawLocal to i18n tooltip
    if measure['perimeter']
      labelText['text'] += "<span class='leaflet-draw-tooltip-measure perimeter'>#{L.GeometryUtil.readableDistance(measure.perimeter, !!options.metric, !!options.feet)}</span>"

    if measure['area']
      labelText['text']  += "<span class='leaflet-draw-tooltip-measure area'>#{L.GeometryUtil.readableArea(measure.area, !!options.metric)}</span>"

    if latLng
      @updateContent labelText
      @__updatePosition latLng, options

    return

  __updatePosition: (latlng, options = {}) ->
    pos = @_map.latLngToLayerPoint(latlng)
    labelWidth = @_container.offsetWidth

    if @_container
      pos = pos.add(L.point(-labelWidth/2, 0))
      @_container.style.visibility = 'inherit'
      container = @_map.layerPointToContainerPoint pos

      if (container.x < 0 || container.y < @_container.offsetHeight) and options.target?
        pos = @_map.latLngToLayerPoint(options.target)
        L.DomUtil.removeClass(@_container, 'leaflet-draw-tooltip-top')

      L.DomUtil.setPosition(@_container, pos)

  hide: ->
    @_container.style.visibility = 'hidden'


###
#Add Configuration options
###

L.DrawToolbar.include
  __initialize: L.DrawToolbar.prototype.initialize

  initialize: (options) ->
    L.DrawToolbar.reactiveMeasure = !!options.reactiveMeasure
    @__initialize.apply this, arguments
    return

L.EditToolbar.include
  __initialize: L.EditToolbar.prototype.initialize

  initialize: (options) ->
    L.EditToolbar.reactiveMeasure = !!options.reactiveMeasure
    @__initialize.apply this, arguments
    return


###
# Leaflet.Draw Patches
 ###
L.EditToolbar.Edit.include
  __removeHooks: L.EditToolbar.Edit::removeHooks
  __revertLayer: L.EditToolbar.Edit::_revertLayer

  # Patch missing event
  removeHooks: ->
    @__removeHooks.apply @, arguments
    if @_map
      @_map.off 'draw:editvertex', @_updateTooltip, @

  # Patch handlers not reverted on cancel edit. See https://github.com/Leaflet/Leaflet.draw/issues/532
  _revertLayer: (layer) ->
    id = L.Util.stamp layer
    @__revertLayer.apply @, arguments
    layer.editing.latlngs = this._uneditedLayerProps[id].latlngs
    layer.editing._poly._latlngs = this._uneditedLayerProps[id].latlngs
    layer.editing._verticesHandlers[0]._latlngs = this._uneditedLayerProps[id].latlngs

L.EditToolbar.include
  # Patch _activeMode is null
  _save: ->
    handler = this._activeMode.handler
    handler.save()
    handler.disable()
