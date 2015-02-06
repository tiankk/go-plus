path = require('path')
_ = require('underscore-plus')
AtomConfig = require('./util/atomconfig')

describe 'gocode', ->
  [workspaceElement, editor, editorView, dispatch, buffer, completionDelay, goplusMain, autocompleteMain, autocompleteManager, provider] = []

  beforeEach ->
    runs ->
      atomconfig = new AtomConfig()
      atomconfig.allfunctionalitydisabled()

      # Enable live autocompletion
      atom.config.set('autocomplete-plus.enableAutoActivation', true)
      atom.config.set('go-plus.suppressBuiltinAutocompleteProvider', false)
      # Set the completion delay
      completionDelay = 100
      atom.config.set('autocomplete-plus.autoActivationDelay', completionDelay)
      completionDelay += 100 # Rendering delay

      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)

      pack = atom.packages.loadPackage('go-plus')
      goplusMain = pack.mainModule
      spyOn(goplusMain, 'provideGocodeProvider').andCallThrough()
      pack = atom.packages.loadPackage('autocomplete-plus')
      autocompleteMain = pack.mainModule
      spyOn(autocompleteMain, 'consumeProvider').andCallThrough()

    waitsForPromise -> atom.workspace.open('gocode.go').then (e) ->
      editor = e
      editorView = atom.views.getView(editor)

    waitsForPromise ->
      atom.packages.activatePackage('autocomplete-plus')

    waitsFor ->
      autocompleteMain.autocompleteManager?.ready

    runs ->
      autocompleteManager = autocompleteMain.autocompleteManager
      spyOn(autocompleteManager, 'displaySuggestions').andCallThrough()

    waitsForPromise ->
      atom.packages.activatePackage('language-go')

    runs ->
      expect(goplusMain.provideGocodeProvider).not.toHaveBeenCalled()
      expect(goplusMain.provideGocodeProvider.calls.length).toBe(0)

    waitsForPromise ->
      atom.packages.activatePackage('go-plus')

    waitsFor ->
      goplusMain.provideGocodeProvider.calls.length is 1

    waitsFor ->
      autocompleteMain.consumeProvider.calls.length is 1

    runs ->
      expect(goplusMain.provideGocodeProvider).toHaveBeenCalled()
      expect(goplusMain.provider).toBeDefined()
      provider = goplusMain.provider
      spyOn(provider, 'requestHandler').andCallThrough()
      expect(_.size(autocompleteManager.providerManager.providersForScopeChain('.source.go'))).toEqual(2)
      expect(autocompleteManager.providerManager.providersForScopeChain('.source.go')[0]).toEqual(provider)
      buffer = editor.getBuffer()
      dispatch = atom.packages.getLoadedPackage('go-plus').mainModule.dispatch
      dispatch.goexecutable.detect()

    waitsFor ->
      dispatch.ready is true

  afterEach ->
    jasmine.unspy(goplusMain, 'provideGocodeProvider')
    jasmine.unspy(autocompleteManager, 'displaySuggestions')
    jasmine.unspy(autocompleteMain, 'consumeProvider')
    jasmine.unspy(provider, 'requestHandler')

  describe 'when the gocode autocomplete-plus provider is enabled', ->

    it 'displays suggestions from gocode', ->
      runs ->
        expect(provider).toBeDefined()
        expect(provider.requestHandler).not.toHaveBeenCalled()
        expect(autocompleteManager.displaySuggestions).not.toHaveBeenCalled()
        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()

        editor.setCursorScreenPosition([5, 6])
        editor.insertText('P')

        advanceClock(completionDelay + 1000)

      waitsFor ->
        autocompleteManager.displaySuggestions.calls.length is 1

      runs ->
        expect(provider.requestHandler).toHaveBeenCalled()
        expect(provider.requestHandler.calls.length).toBe(1)
        expect(editorView.querySelector('.autocomplete-plus')).toExist()
        expect(editorView.querySelector('.autocomplete-plus span.word')).toHaveText('Print(')
        expect(editorView.querySelector('.autocomplete-plus span.completion-label')).toHaveText('func(a ...interface{}) (n int, err error)')
        editor.backspace()

    it 'does not display suggestions when no gocode suggestions exist', ->
      runs ->
        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()

        editor.setCursorScreenPosition([6, 15])
        editor.insertText('w')

        advanceClock(completionDelay + 1000)

        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()

    it 'does not display suggestions at the end of a line when no gocode suggestions exist', ->
      runs ->
        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()

        editor.setCursorScreenPosition([5, 15])
        editor.backspace()
        editor.insertText(')')
        advanceClock(completionDelay + 1000)

      waitsFor ->
        autocompleteManager.displaySuggestions.calls.length is 1

      runs ->
        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()
        editor.insertText(';')

      waitsFor ->
        autocompleteManager.displaySuggestions.calls.length is 2
        advanceClock(completionDelay + 1000)

      runs ->
        expect(editorView.querySelector('.autocomplete-plus')).not.toExist()
