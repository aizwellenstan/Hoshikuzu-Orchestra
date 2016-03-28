###

###


applyTargetOption = (target, note, CompObj) ->
    ###
    ここで位置などの値を適応しています
    note.intime   :  開始時間
    note.pitch    :  音の高さ。値は0～126
    note.velocity :  音の強さ。値は0～126
    ###
    target.name = "Note_"+note.pitch
    target("position").setValue([CompObj.width/2+(note.pitch-64)*50,CompObj.height/2+(note.velocity-64)*-7]);
    target("scale").setValue([note.velocity*1.3,note.velocity*1.3]);
    return


# スコープ外オブジェクト
MIDI = {
    file:null # バイナリファイルを格納
    length:null # バイナリ長さ
    chunktype:null # SMF形式かを判定できる。通常4D546864
    bytes:[] # 読みやすく1バイトごとに分けた配列
    tracksize:null # トラック数
    tracks:[] # 各トラックの情報を格納
    timeunit:null # 時間単位。通常は01E0で、分解能が480で何小節何拍という形式であるということを表す
    tempo:"" # テンポ。4分音符のミリ秒。BPM120で500000
    tmp:{ #一時保存したいものとか
        cur_deltatime:0
        last_note_code:""
    }
}

activeItem = app.project.activeItem #選択されてるアイテム

# バイナリコードを人間的に判定しやすいByteに変換
convertBin2Byte = (offset) ->
    if !MIDI.file?
        $.writeln "MIDI.fileがないのにconvertBin2Byte"
        return false
    c = MIDI.file.charCodeAt(offset).toString(16).toUpperCase()
    if c<10
        c = 0 + String c
    return String c

# MIDIを取得してBytesの配列を作成
getMidiFile = ->
    @FilePath = File.openDialog("MIDIファイルを選択してください","*.mid")
    myFile = new File @FilePath;
    $.writeln(myFile.fsName)
    myFile.encoding = "BINARY"
    $.writeln(myFile.encoding)
    if !myFile.open("r")
        alert "ファイルがオープンできませんでした"
        return false
    MIDI.length = myFile.length;
    MIDI.file = myFile.read(MIDI.length);
    myFile.close()
    MIDI.bytes = []
    for i in [0...MIDI.length]
        n = convertBin2Byte(i)
        # $.writeln("["+i+"] : "+n)
        MIDI.bytes.push(n)
    if !MIDI.bytes?
        alert "データ取得不可"
        return false
    # バイト位置指定でヘッダー情報類を読み出します
    MIDI.chunktype = MIDI.bytes[0]+MIDI.bytes[1]+MIDI.bytes[2]+MIDI.bytes[3]
    MIDI.tracksize = parseInt(MIDI.bytes[10],16)+parseInt(MIDI.bytes[11],16);
    MIDI.timeunit = MIDI.bytes[12]+MIDI.bytes[13];

    $.writeln("■■■■■")
    $.writeln "MIDI.length : #{MIDI.length}"
    $.writeln "MIDI.chunktype : #{MIDI.chunktype}"
    $.writeln "MIDI.tracksize : #{MIDI.tracksize}"
    $.writeln "MIDI.timeunit : #{MIDI.timeunit}"
    $.writeln("■■■■■")

    #SMFであることが確認できたら
    if MIDI.chunktype == "4D546864"
        mainloop()

mainloop = ->
    i = 14
    while i < MIDI.length
        # if i > 50
        #     $.writeln "デバックにつき一旦中断"
        #     break

        # トラック開始の判定
        if MIDI.bytes[i]+MIDI.bytes[i+1]+MIDI.bytes[i+2]+MIDI.bytes[i+3] == "4D54726B"
            $.writeln "トラックの開始"
            MIDI.tracks[MIDI.tracks.length] = {
                name:""
                size:parseInt(MIDI.bytes[i+4]+MIDI.bytes[i+5]+MIDI.bytes[i+6]+MIDI.bytes[i+7],16)
                notes:[]
            }
            MIDI.tmp.cur_deltatime = 0
            MIDI.tmp.last_note_code = ""
            i+=8
            continue

        # まずは必ずデルタタイム
        # 0x80以上なら次の値もデルタタイムと考える
        # $.writeln " ? : #{MIDI.bytes[i]}"
        # $.writeln "デルタタイムフェーズ#{i}"
        b = 0
        deltatimes = []
        while b < MIDI.tracks[MIDI.tracks.length-1].size
            deltatimes.push(MIDI.bytes[i+b])
            # $.write "#{MIDI.bytes[i+b]}"
            if parseInt(MIDI.bytes[i+b],16) < parseInt("80",16)
                break
            b++
        i += b+1

        # deltatimesの計算
        deltatime_bit = ""
        for dt in deltatimes
            # 上位1ビットを削除して連結する
            tmp_bit = parseInt(dt,16).toString(2)
            # 空白を0で埋める
            space_bit = ""
            for bit in [0..(8-tmp_bit.length)]
                space_bit += "0"
            deltatime_bit = deltatime_bit+String(space_bit+tmp_bit).substr(-7)
        # $.writeln deltatime_bit
        cur_deltatime = parseInt(deltatime_bit,2)
        # $.writeln "cur_deltatime: #{cur_deltatime}"
        MIDI.tmp.cur_deltatime = MIDI.tmp.cur_deltatime+cur_deltatime
        # $.writeln "deltatime: #{MIDI.tmp.cur_deltatime}"

        # このループで読み進んだバイト数
        read_byte = 0

        ## コントロールイベントの判定
        if MIDI.bytes[i] == "FF"
            ## データ長を確認
            l = parseInt(MIDI.bytes[i+2],16)

            # トラック名を取得
            if MIDI.bytes[i+1] == "03"
                for k in [i+3...i+3+l]
                    MIDI.tracks[MIDI.tracks.length-1].name += "%"+MIDI.bytes[k]
                MIDI.tracks[MIDI.tracks.length-1].name = decodeURI(MIDI.tracks[MIDI.tracks.length-1].name)
                $.writeln "トラック名:#{MIDI.tracks[MIDI.tracks.length-1].name}"
                $.writeln "トラックサイズ:#{MIDI.tracks[MIDI.tracks.length-1].size}"

            # テンポを取得
            else if MIDI.bytes[i+1] == "51"
                for k in [i+3...i+3+l]
                    MIDI.tempo += MIDI.bytes[k]
                MIDI.tempo = parseInt(MIDI.tempo,16)
                $.writeln "テンポ:#{MIDI.tracks[MIDI.tracks.length-1].tempo}"

            # 拍子を取得
            # 今のところ使う予定ないし放置
            else if MIDI.bytes[i+1] == "58"
                $.writeln "拍子情報を発見"

            # キーを取得
            # 今のところ使う予定ないし放置
            else if MIDI.bytes[i+1] == "59"
                $.writeln "キー情報を発見"

            # トラック終了の判定
            else if MIDI.bytes[i+1] == "2F"
                $.writeln "トラックの終了:#{MIDI.tracks[MIDI.tracks.length-1].name}"

            else
                $.writeln "それ以外のイベント#{MIDI.bytes[i+1]}を発見"

            read_byte += 2+l

        # ノートオンイベントを取得
        else if MIDI.bytes[i] == "9#{MIDI.tracks.length-2}"
            # $.writeln "ノートオンイベントを発見:#{MIDI.tracks[MIDI.tracks.length-1].notes.length+1} ■ #{parseInt(MIDI.bytes[i+1],16)} ■#{parseInt(MIDI.bytes[i+2],16)}"
            $.write "."
            note = {
                intime:MIDI.tmp.cur_deltatime
                # outtime:""
                pitch:parseInt(MIDI.bytes[i+1],16)
                velocity:parseInt(MIDI.bytes[i+2],16)
            }
            MIDI.tracks[MIDI.tracks.length-1].notes.push(note)
            MIDI.tmp.last_note_code = "9#{MIDI.tracks.length-2}"
            read_byte += 2

        # ノートオフイベントを取得
        # 今のところ使う予定ないし放置
        else if MIDI.bytes[i] == "8#{MIDI.tracks.length-2}"
            # $.writeln "ノートオフイベントを発見 ■ #{parseInt(MIDI.bytes[i+1],16)} ■#{parseInt(MIDI.bytes[i+2],16)}"
            MIDI.tmp.last_note_code = "8#{MIDI.tracks.length-2}"
            read_byte += 2

        # コントロールイベントを取得
        # 今のところ使う予定ないし放置
        else if parseInt("A0",16) <= parseInt(MIDI.bytes[i],16) <= parseInt("EF",16)
            $.writeln "コントロールイベントを発見"
            read_byte += 2

        else # 8x/9xが省略されているため、前回のノートオン/ノートオフコードを引き継ぐ
            # $.writeln "前回のノートコードの省略？"
            # ノートオンイベントを取得
            if MIDI.tmp.last_note_code == "9#{MIDI.tracks.length-2}"
                # $.writeln "ノートオンイベントを発見:#{MIDI.tracks[MIDI.tracks.length-1].notes.length+1} ■ #{parseInt(MIDI.bytes[i],16)} ■#{parseInt(MIDI.bytes[i+1],16)}"
                $.write "."
                note = {
                    intime:MIDI.tmp.cur_deltatime
                    # outtime:""
                    pitch:parseInt(MIDI.bytes[i],16)
                    velocity:parseInt(MIDI.bytes[i+1],16)
                }
                MIDI.tracks[MIDI.tracks.length-1].notes.push(note)
                MIDI.tmp.last_note_code = "9#{MIDI.tracks.length-2}"
                read_byte += 1

            # ノートオフイベントを取得
            # 今のところ使う予定ないし放置
            else if MIDI.tmp.last_note_code == "8#{MIDI.tracks.length-2}"
                # $.writeln "ノートオフイベントを発見 ■ #{parseInt(MIDI.bytes[i+1],16)} ■#{parseInt(MIDI.bytes[i+2],16)}"
                MIDI.tmp.last_note_code = "8#{MIDI.tracks.length-2}"
                read_byte += 1

        i += read_byte+1

    # Note位置取得処理が完了
    applyToComp()

    return true


# 実際にアフターエフェクトのコンポに落とし込んでいく
applyToComp = ->
    # 管理用コンプを追加
    ex_time = print_time()
    # folderObj = app.project.items.addFolder("_midi_result #{ex_time}")
    noteNum = 0
    CompObj = app.project.items.addComp("MIDI #{ex_time} "+noteNum+"~", 1920, 1080, 1.0, 10*60, 29.97);
    for track in MIDI.tracks
        for note in track.notes
            if noteNum%400 == 399
                CompObj = app.project.items.addComp("MIDI #{ex_time} "+noteNum+"~", 1920, 1080, 1.00, 600, 29.97)

            target = CompObj.layers.add(app.project.activeItem)
            target.startTime = note.intime/parseInt(MIDI.timeunit,16)*MIDI.tempo*0.000001
            applyTargetOption(target,note, CompObj)
            noteNum++
            # $.writeln "Note #{noteNum} : #{target.startTime}"


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
        alert "複製配置したいコンポジションを選択した状態で実行して下さい"
        return false
    if confirm "現在選択されているコンポジションを複製配置します。"
        return true
    return false


# 開始
go = ->
    return unless checkCanExcute()
    getMidiFile()


go()