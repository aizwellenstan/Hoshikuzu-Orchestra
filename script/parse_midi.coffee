###
midiを取得し、新規コンポを作成、そのタイミングに合わせて何かを追加
fork by : http://omino.com/pixelblog/2011/12/26/ae-hello-again-midi/

参考 : [JavaScriptでMIDIファイルを解析してみる 1](http://qiita.com/PianoScoreJP/items/2f03ae61d91db0334d45)

###

#option
comp_length = 10


main = ->
    activeItem = app.project.activeItem
    return unless checkCanExcute()

    # 管理用コンプを追加
    ex_time = print_time()
    # folderObj = app.project.items.addFolder("_midi_result #{ex_time}")
    CompObj = app.project.items.addComp("_result #{ex_time}", 1920, 1080, 1.0, comp_length, 29.97);


# 現在時刻の文字列を取得
# string
print_time = ->
    date = new Date()
    hour = date.getHours();
    minute = date.getMinutes();
    second = date.getSeconds();
    return "#{hour}:#{minute}:#{second}"

# 実行可能な状態かどうか
# boolean
checkCanExcute = ->
    # 複製用コンプの存在確認
    if (activeItem == null) or !(activeItem instanceof CompItem)
        alert "コンポジションを選択した状態で実行しよう"
        return false
    alert "コンポが選択されてる"
    return true

readMidiHex = (file_path) ->
    file = new File(file_path)
    file.encoding = "BINARY"
    file.open ("r")
    length = file.length
    result = file.read(length).toString("hex").toUpperCase()
    file.close()
    return result

# main()

MIDI = readMidiHex("../src/ignore/piano.mid")
res = MIDI.substring(20,24)
alert(res);