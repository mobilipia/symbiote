ISO_SKEW = 25
ISO_MAJOR_OFFSET = 50
ISO_MINOR_OFFSET = 5
SCREEN_BOUNDS = {
  iphone: { x: 0, y: 0, width: 320, height: 480 }
  ipad: { x: 0, y: 0, width: 768, height: 1024 }
}
#SCREENSHOT_URL = symbiote.baseUrlFor( "screenshot" )

define ['transform_stack','ersatz_model'], (transformStack,ErsatzModel)->

  drawStaticBackdropAndReturnTransformer = (paper,deviceFamily,isoSkew) ->
    paper.clear()
    paper.canvas.setAttribute "width", "100%"
    paper.canvas.setAttribute "height", "100%"

    if 'iphone' == deviceFamily
      paper.canvas.setAttribute "viewBox", "0 0 380 720"
    else
      paper.canvas.setAttribute "viewBox", "0 0 875 1200"

    transformer = transformStack()
    transformer.skew(0, isoSkew).translate( 6, 6 )


    # main outline of device
    if 'iphone' == deviceFamily
      paper.rect(0, 0, 360, 708, 40).attr(
        fill: "black"
        stroke: "gray"
        "stroke-width": 4
      ).transform transformer.desc()
    else
      paper.rect( 10, 10, 855, 1110, 20 ).attr(
        'fill': 'black',
        'stroke': 'gray',
        'stroke-width': 6
      ).transform transformer.desc()


    if 'iphone' == deviceFamily
      # home button
      transformer.push().translate( 180, 655 )
      paper.circle(0, 0, 34).transform(transformer.desc()).attr( "fill", "90-#303030-#101010" )
   
      # square inside home button
      paper.rect(0, 0, 22, 22, 5).attr(
        stroke: "gray"
        "stroke-width": 2
      ).transform transformer.push().translate(-11, -11).descAndPop()

      transformer.translate(20, 120)

    else
      transformer.translate(50,50)

    if( isoSkew > 0 )
      transformer.translate(-ISO_MAJOR_OFFSET, 0)
    transformer


  transformFromBaseForViewModel = (baseTransformer,viewModel,withSkew=false)->
    {origin:{x,y}} = viewModel.get('accessibilityFrame')
    baseTransformer.push().translate(x,y)
    if( withSkew )
      baseTransformer.translate(viewModel.get('depth')*-ISO_MINOR_OFFSET, 0)
    baseTransformer.descAndPop()

  ErsatzViewSnapshotView = Backbone.View.extend
    initialize:->
      @model.on('change:active',_.bind(@updateOpacity,@))
      @render()

    render: ->
      frame = @model.get('accessibilityFrame')
      @el
        .attr
          transform: transformFromBaseForViewModel( @options.baseTransformer, @model,true )
          src: @model.getSnapshotUrl()
          x: 0
          y: 0
          width: frame.size.width
          height: frame.size.height
      @updateOpacity()
      @el

     updateOpacity: ->
       opacity = ( if @model.get('active') then 1.0 else 0.05 )
       @el.attr('opacity',opacity)


  ErsatzView = Backbone.View.extend
    el: $('#ui-locator-view')

    initialize: ->
      _.bindAll( @, 'render' )
      @model = new ErsatzModel()
      @paper = new Raphael(@.el)
      @model.on 'change:baseScreenshotUrl', _.bind(@refreshBaseScreenshot,@)
      @model.on 'change:isAsploded', _.bind(@render,@)
      @model.on 'snapshots-refreshed', _.bind(@refreshSnapshots,@)
      @model.on 'change:allViews', =>
        @model.get('allViews').on 'change:active', (subject,isActive)=>
          if isActive
            @highlight.show()
            @updateHighlight(subject)
          else
            @highlight.hide()

    render: ->
      isoSkew = (if @model.get('isAsploded') then ISO_SKEW else 0)
      @backdropTransformer = drawStaticBackdropAndReturnTransformer(@paper,@model.get('deviceFamily'),isoSkew)
      @backdrop = @paper.image()
      @refreshBaseScreenshot()
      if @model.get('isAsploded')
        @backdrop.attr('opacity',0.5)
        @refreshSnapshots()

      @highlight = @paper.rect().attr(
        fill: "#aaff00"
        opacity: 0.8
        stroke: "black"
      )

      @el

    screenBounds: -> SCREEN_BOUNDS[@model.get('deviceFamily')]


    refreshBaseScreenshot: ->
      newScreenshotUrl = @model.get('baseScreenshotUrl')
      return unless newScreenshotUrl?

      @backdrop
        .transform(@backdropTransformer.desc())
        .attr( @screenBounds() )
        .attr( 'src', newScreenshotUrl )
        .toFront()

    refreshSnapshots: ->
      @model.get('allViews').each (viewModel) =>
        snapshotView = new ErsatzViewSnapshotView(
          model: viewModel
          baseTransformer: @backdropTransformer
          el: @paper.image()
        )

     updateHighlight: (viewModel)->
       if @model.get('isAsploded')
         @highlight.hide()
         return
       else
         @highlight.show()

       frame = viewModel.get('accessibilityFrame')
       @highlight.attr(
          transform: transformFromBaseForViewModel(@backdropTransformer,viewModel, false )
          x: 0
          y: 0
          width: frame.size.width
          height: frame.size.height
       ).toFront()


        #ErsatzView.
        #frame = view.get('accessibilityFrame')
        #transformation = @backdropTransformer
          #.push()
          #.translate(frame.origin.x, frame.origin.y)
          #.translate(view.get('depth')*-ISO_MINOR_OFFSET, 0)
          #.descAndPop()

        #@paper
         #.image( view.getSnapshotUrl(), 0, 0, frame.size.width, frame.size.height )
         #.transform(transformation)
