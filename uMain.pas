unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, ActiveX, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, ShellAPI, IniFiles,
  Vcl.Imaging.pngimage, DateUtils, Vcl.ComCtrls;

type
  TfrmMain = class(TForm)
    lbLog: TListBox;
    QuitTimer: TTimer;
    pnlOptions: TPanel;
    btnStart: TButton;
    rbCheckAll: TRadioButton;
    rbCheckWeek: TRadioButton;
    chkDeleteBMP: TCheckBox;
    chkConvertBMP: TCheckBox;
    chkCheckPalette: TCheckBox;
    chkCheckColor: TCheckBox;
    rbCheckOpen: TRadioButton;
    txtInputDir: TEdit;
    Label1: TLabel;
    txtDays: TEdit;
    udDays: TUpDown;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure QuitTimerTimer(Sender: TObject);
    procedure lbLogClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ChangeOptions(Sender: TObject);
    procedure udDaysClick(Sender: TObject; Button: TUDBtnType);
  private
    function CommandLineParcing: Boolean;
//    function CheckPrinter(pName: String): Boolean;
    function ScanJob: Boolean;
    procedure SaveSettings;
//    function MakeCheck: Boolean;
    { Private declarations }
  public
    { Public declarations }
  end;

//const
//    iniFileName = 'PngScan.ini';

var
    myIni: TIniFile;
    frmMain: TfrmMain;
    LogList: TStringList;                                                       //���� ��� �����������
    InputDir: String;                                                           //���������� ��� ���������
    WorkList: TStringList;                                                      //����������� ������ ����
    bCancelFlag: Boolean;                                                       //���� ������ �� ����������� ��������� ����������
    fCount, fCountAll: Integer;                                                 //������� ������������ � ����������� ������
    iDaysAgo: Integer;                                                          //�� ��������� N ����
    iScanMode: Integer;                                                         //����������� ������� ������������ ���� ��� ����� � ������ ������
    bCheckColor: Boolean;                                                       //��������� ���������
    bCheckPalette: Boolean;                                                     //���������� ������ �������
    bConvertBMP: Boolean;                                                       //�������������� BMP ���� �� ���������� PNG
    bDeleteBMP: Boolean;                                                        //������� BMP ���� ������ ���� ����� �� PNG

procedure ExecuteWait(const sProgramm: string; const sParams: string = ''; fHide: Boolean = false);
function TryOpenFile(fName: String): Boolean;
function GetBitDepth(FName: String): Integer;
procedure Log(Val: Integer); overload;
procedure Log(Text: String); overload;
procedure Log(Flag: Boolean); overload;
procedure Log(Text: String; Val: variant); overload;
procedure Log(Strs: TStrings); overload;
procedure Log(Arr: array of byte; Count: Integer = 0; Msg: String = ''); overload;
procedure Log(Stream: TStream; Count: Integer = 0; Msg: String = ''); overload;
procedure ErrorLog(e: Exception; Method: String = ''; ShowMsg: Boolean = True; isFatal: Boolean = False);
function FileOlderThanWeek(fName: String): boolean;
function CheckPNGPalette(FName: String): Integer;
function GetPNGColorType(FName: String): Integer;
function RemoveTransparensy(FName: String): Boolean;
procedure ProcessFile(fName:String);
procedure ConvertBMP2PNG(fName: String);
procedure DeleteBMPifPNGexists(fName: String);
procedure CheckPNGColor(fName: String);

implementation
{$R *.dfm}
uses Printers;

{$REGION '�����������'}
procedure Log(Text: String);
begin
	LogList.Add({TimeToStr(Now) +}'> '+ Text);
    if Assigned(frmMain) then begin
    frmMain.lbLog.Items.Add({TimeToStr(Now) +}'> '+ Text);
   	frmMain.lbLog.ItemIndex:=frmMain.lbLog.Items.Count-1;
    end;
end;
procedure Log(Val: Integer);
begin
	Log(IntToStr(Val));
end;
procedure Log(Flag: Boolean);
begin
    if Flag then Log('True') else Log('False');
end;
procedure Log(Strs: TStrings);
begin
    LogList.AddStrings(Strs);
    if Assigned(frmMain) then begin
	   frmMain.lbLog.Items.AddStrings(Strs);
        end;
end;

procedure Log(Arr: array of byte; Count: Integer = 0; Msg: String = '');
var
    s: string;
    i, imx: integer;
begin
    if Msg <> '' then begin
        Log('Array: ' + Msg);
        Log('Count:'+ IntToStr(Count) + ', size:' +IntToStr(SizeOf(arr)));
    end;
    if (Count <= 0) or (Count > SizeOf(arr) ) then imx:= SizeOf(arr)
    else imx:= Count;
    if imx > 100 then imx:= 100;
    for i := 0 to imx do s:=s + arr[i].ToHexString(2) + ' ';
    Log(s);
end;
procedure Log(Stream: TStream; Count: Integer = 0; Msg: String = '');
var
    s: string;
    i, imx: integer;
    h: Byte;
    p: Dword;
begin
    p:=Stream.Position;
    Stream.Position:=0;
    if Msg <> '' then begin
        Log('Stream: ' + Msg);
        Log('Count:'+ IntToStr(Count) + ', size:' +IntToStr(Stream.Size));
    end;
    if (Count <= 0) or (Count > Stream.Size) then imx:= Stream.Size
    else imx:=Count;
    if imx > 100 then imx:= 100;
    for i := 0 to imx do begin
            Stream.Read(h, 1);
            s:= s + h.ToHexString(2) + ' ';
    end;
    Stream.Position:=p;
    Log(s);
end;

procedure Log(Text: String; Val: variant);
begin
	Log(Text + ' ' + VarToStr(Val));
end;

procedure ErrorLog(e: Exception; Method: String = ''; ShowMsg: Boolean = True; isFatal: Boolean = False);
//����������� ������
//�������� isFatal ���������� ��������� ���������
begin
    Log('Error : ' + e.ClassName);
    if Method<>'' then Log('    Procedure: ' + Method);
    Log('    Error Message: ' + e.Message);
    Log('    Except Address: ', IntToHex(Integer(ExceptAddr), 8));
    if isFatal then begin
        LogList.SaveToFile('log_'+ DateToStr(now) +'.txt');
        Application.Terminate;
    end;
    if ShowMsg then MessageBox(Application.ActiveFormHandle, PWideChar('I''m sorry, but error occured!' + #13#10 +
                                                    'Code:' + e.ClassName + #13#10 +
                                                    'Method: ' + Method + #13#10 +
                                                    'Message: ' + e.Message + #13#10 +
                                                    'Address: ' + IntToHex(Integer(ExceptAddr), 8)), 'Error', MB_APPLMODAL + MB_OK + MB_ICONERROR);
end;
{$ENDREGION}

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
//��� ������ ��������������� ����� � ����������
// ������� ���������� != ����� � ����������
//������� ����� �� ������ ����, ������ �� ����� � ����������
var
    ProgramDir, frmDT: String;
begin
    if bCancelFlag then Exit;                                                   //���� ������ ��� �������, ������ ��������� ����� ����������
    SaveSettings;                                                               //������ �������� � INI
    bCancelFlag:=True;
    DateTimeToString(frmDT, 'yymmdd_hhmm', Now);
    ProgramDir:=ExtractFilePath(Application.ExeName);                           //�� ExtractFileDir, ��������� ����
    LogList.SaveToFile(ProgramDir + 'scan_log_' + frmDT + '.txt');
    if WorkList.Count <> 0 then
        WorkList.SaveToFile(ProgramDir + 'work_log_' + frmDT + '.txt');
end;

procedure TfrmMain.SaveSettings;
begin
    MyIni.WriteString('Options', 'InputDir', txtInputDir.Text);
    MyIni.WriteInteger('Options', 'Days', udDays.Position);
    MyIni.WriteInteger('Options', 'ScanMode', iScanMode);
    MyIni.WriteBool('Options', 'CheckColor', chkCheckColor.Checked);
    MyIni.WriteBool('Options', 'CheckPalette', chkCheckPalette.Checked);
    MyIni.WriteBool('Options', 'ConvertBMP', chkConvertBMP.Checked);
    MyIni.WriteBool('Options', 'DeleteBMP', chkDeleteBMP.Checked);
    //����� ���������� �� �������� � ����������
    //Ÿ ������ ������������ ��� ������ ���������.
    //�� ��� ������ ���� � ����� INI, ����� ������������ � ��� ����
    if not MyIni.ValueExists('Options', 'Autostart') then
        MyIni.WriteBool('Options', 'Autostart', False);

end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
    LogList:=TStringList.Create;
    WorkList:=TStringList.Create;
    bCancelFlag:=False;
    fCount:=0;
    fCountAll:=0;
    Self.Show;
    Log('�����');
    MyIni:= TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini'));
    //��������������, ��� ����� �������� ���, �� �� �� ����� ����� ������ ��� ������
    if not FileExists(ChangeFileExt(Application.ExeName,'.ini')) then
        Log('��������������! ���� �������� ' + ChangeFileExt(Application.ExeName,'.ini')+ ' �� ������!');
    MyIni:= TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini'));
    //������ ��������� � ��������, � �� ��������� �� ���������� ����������
    txtInputDir.Text:= MyIni.ReadString('Options', 'InputDir', 'e:\scan\2\');
    udDays.Position:= MyIni.ReadInteger('Options', 'Days', 7);
    iScanMode:= MyIni.ReadInteger('Options', 'ScanMode', 0);
    rbCheckAll.Checked:= (iScanMode=0);
    rbCheckWeek.Checked:= (iScanMode=1);
    rbCheckOpen.Checked:= (iScanMode=2);
    chkCheckColor.Checked:= MyIni.ReadBool('Options', 'CheckColor', False);
    chkCheckPalette.Checked:= MyIni.ReadBool('Options', 'CheckPalette', False);
    chkConvertBMP.Checked:= MyIni.ReadBool('Options', 'ConvertBMP', False);
    chkDeleteBMP.Checked:= MyIni.ReadBool('Options', 'DeleteBMP', False);
    //������������� �������� ��������� ���������, �.�. �� ��� �������� ���������
    // �� ���������� ���������
    ChangeOptions(nil);

    log('��������� ����� �� ' + ChangeFileExt(Application.ExeName,'.ini'));
    Log('��������� ��, ��. = ', iDaysAgo);
    Log('����� = ', iScanMode);
    Log('�������� ����� ', bCheckColor);
    Log('�������� ������� ', bCheckPalette);
    Log('��������������� BMP > PNG ', bConvertBMP);
    Log('�������� BMP ', bDeleteBMP);
    Log('����� ������� ' + (ExtractFileDir(Application.ExeName)));
    Log('');
    //���� � ��������� ������ ���� ������ ����� ��� � ���������� �������
    //���������, �� �������� ���������������, ��� ������������� ������������
    //��������, ��������� ����� �������� ������ � INI �����
    if CommandLineParcing or MyIni.ReadBool('Options', 'Autostart', False) then begin
        ScanJob;
        Log('�������� ����� 5�.');
        QuitTimer.Enabled:=True;
    end else begin
        pnlOptions.Visible:=True;
    end;
end;

procedure TfrmMain.lbLogClick(Sender: TObject);
begin
    if QuitTimer.Enabled then begin
        Log('�������� ��������');
        QuitTimer.Enabled:=False;
    end;
end;

procedure TfrmMain.ChangeOptions(Sender: TObject);
begin
    //������� �������� �������� ��������������� ��������� ����
    bConvertBMP:=chkConvertBMP.Checked;
    bDeleteBMP:=chkDeleteBMP.Checked;
    bCheckColor:=chkCheckColor.Checked;
    bCheckPalette:=chkCheckPalette.Checked;
    InputDir:=IncludeTrailingBackslash(txtInputDir.Text);
    iDaysAgo:=udDays.Position;
    if rbCheckAll.Checked then iScanMode:=0
        else if rbCheckWeek.Checked then iScanMode:=1
        else if rbCheckOpen.Checked then iScanMode:=2;
end;

function TfrmMain.CommandLineParcing: Boolean;
//����� ������������� ����� ����������� � ���������� (�� �����)
begin
result:=false;
Log('������ �������: ' + CmdLine);
if (ParamStr(1)='') then Begin
    Log('��������� ������ �� �������� ����������');
    Log('����������� ��������� � �����������:');
    Log('PngScaner <inputfolder> ');
    Log('   <inputfolder> - ����� � ������� ��� ���������');
    Log('��� ��������� ��������� �������');
    exit;
end;

InputDir:=IncludeTrailingBackslash(ParamStr(1));

Log('������ ������� �����');
result:=true;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
    QuitTimer.Enabled:=False;
    pnlOptions.Visible:=false;
    ScanJob;
end;

procedure ScanDir(StartDir: String; Mask:string);
//��������, ����������� �������
//���������� ��� ���������� � �������� ProcessFile ��� ������� �����
var
    SearchRec : TSearchRec;
begin
if bCancelFlag then exit;
if Mask ='' then Mask:= '*.*';
StartDir:=IncludeTrailingBackslash(StartDir);
if FindFirst(StartDir + Mask, faAnyFile, SearchRec) = 0 then begin
    Log(StartDir);
    frmMain.Caption:=Application.Title + ' [' + IntToStr(fCountAll) + '/' + IntToStr(fCount) + ']';
    Repeat
        Application.ProcessMessages;
        if (SearchRec.Attr and faDirectory) <> faDirectory then begin
            ProcessFile(StartDir + SearchRec.Name);
            inc(fCountAll);
        end
        else if (SearchRec.Name <> '..') and (SearchRec.Name <> '.') then begin
            ScanDir(StartDir + SearchRec.Name + '\', Mask);
        end;
    Until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
end
end;

function TfrmMain.ScanJob: Boolean;
begin
    Log('����� ��� ���������: ' + InputDir);
    Log('����� ������');
    ScanDir(InputDir, '*.*');
    Log('');
    Log('���������� ������: ', fCount);
    Log('����� ������: ', fCountAll);
    if fCountAll = 0 then begin
        Log('����� �� ������� :(');
        Exit;
    end;
    Result:=True;
end;

procedure TfrmMain.udDaysClick(Sender: TObject; Button: TUDBtnType);
begin
    ChangeOptions(Sender);
end;

function TryOpenFile(FName: String): Boolean;
//�������� �������� ����� �� �������
var
  FS: TFileStream;
begin
try
    Result := True;
    FS := TFileStream.Create(Fname, fmOpenRead);
    FS.Free;
except
    Log(FName + ' -> ������ �������');
    WorkList.Add(FName + ' -> ������ �������');
    Result := False;
end;

end;

function GetFSize(FName: String): Long;
var
  FS: TFileStream;
begin
  try
    FS := TFileStream.Create(Fname, fmOpenRead);
  except
    Result := -1;
  end;
  if Result <> -1 then Result := FS.Size;
  FS.Free;
end;

function GetBitDepth(FName: String): Integer;
var
  Png: TPngImage;
begin
  try
    Png := TPngImage.Create;
    Png.LoadFromFile(fName);
  except
    Result := -1;
  end;
    if Result <> -1 then
        Result := Integer(Png.Header.BitDepth);
  png.Free;
end;

function RemoveTransparensy(FName: String): Boolean;
var
  Png: TPngImage;
begin
  try
    Png := TPngImage.Create;
    Png.LoadFromFile(fName);
    if Png.TransparencyMode <> ptmNone then begin
        Png.RemoveTransparency;
        Png.SaveToFile(fName);
        Log(fName + ' -> ��������� ������������');
        WorkList.Add(fName + ' -> ��������� ������������');
    end;
  except end;
  Result := True;
  png.Free;
end;

function CheckPNGPalette(FName: String): Integer;
//��� ������ PNG � �������� (ColorType = COLOR_PALETTE)
//�����������, ��� � ������� �� ����� ���� ������,
//� ��� ������� �����-����� ��� ����� (��� ������ ������)
//������������ �����������
var
    Png: TPngImage;
    PaletteHandle: HPALETTE;
    Palette: array[Byte] of TPaletteEntry;
    PalCount: Integer;
begin
  try
    Png := TPngImage.Create;
    Png.LoadFromFile(fName);
    if not (Png.Header.ColorType = COLOR_PALETTE) then begin
        Result:=-1;
        Png.Free;
        Exit;
    end;

    PaletteHandle := Png.Palette;
    PalCount:=GetPaletteEntries(PaletteHandle, 0, 256, Palette);
    if PalCount > 2 then begin
        Log(fName + ' -> ������������ ������� (' + IntToStr(PalCount) + ')');
        if PalCount>2 then WorkList.Add(fName + ' -> ������������ ������� (' + IntToStr(PalCount) + ')');

    end;
    if (PalCount = 2) and
        ((Palette[0].peRed = $FF) and
        (Palette[0].peGreen = $FF) and
        (Palette[0].peBlue = $FF) and
        (Palette[1].peRed = $00) and
        (Palette[1].peGreen = $00) and
        (Palette[1].peBlue = $00)) or
        ((Palette[1].peRed = $FF) and
        (Palette[1].peGreen = $FF) and
        (Palette[1].peBlue = $FF) and
        (Palette[0].peRed = $00) and
        (Palette[0].peGreen = $00) and
        (Palette[0].peBlue = $00))
        then begin
            Log(FName + ' -> ������� OK');
            result:=0;
            Png.Free;
            exit;
    end;
    if (PalCount = 1) and
        ((Palette[0].peRed = $FF) and
        (Palette[0].peGreen = $FF) and
        (Palette[0].peBlue = $FF)) then begin
            Log(FName + ' -> ������� �� ���� ����.');
            //WorkList.Add(FName + ' -> ������� �� ���� ����.');
            result:=0;
            Png.Free;
            exit;
    end else begin
        Palette[0].peRed:= $FF;
        Palette[0].peGreen:= $FF;
        Palette[0].peBlue:= $FF;
    end;

    if (PalCount = 2) then begin
        Palette[0].peRed := $FF;
        Palette[0].peGreen:= $FF;
        Palette[0].peBlue := $FF;
        Palette[0].peFlags:= $00;
        Palette[1].peRed := $00;
        Palette[1].peGreen := $00;
        Palette[1].peBlue := $00;
        Palette[1].peFlags:= $00;
    end;
    SetPaletteEntries(PaletteHandle, 0, PalCount, Palette);
    Png.Palette := PaletteHandle;
    Png.RemoveTransparency;
    Png.CompressionLevel:= 9;
    CopyFile(PWideChar(FName), PWideChar(ChangeFileExt(FName, '.bak')), False);
    Png.SaveToFile(Fname);
    inc(fCount);
    Log(FName + ' -> ������� ����������.');
    WorkList.Add(FName + ' -> ������� ���������� ('  + IntToStr(PalCount) + ')');

  except
    Result := -1;
    Log(fname + ' -> �������� � ������������ �������.');
    WorkList.Add(FName + ' -> �������� � ������������ �������.');
  end;
    Png.Free;
end;

function GetPNGColorType(FName: String): Integer;
var
  Png: TPngImage;
begin
  try
    Png := TPngImage.Create;
    Png.LoadFromFile(fName);
  except
    Result := -1;
  end;
    if Result <> -1 then begin
        Result := Integer(Png.Header.ColorType);
        Png.Free;
    end;
end;

procedure TfrmMain.QuitTimerTimer(Sender: TObject);
begin
    Self.Close;
end;

procedure ExecuteWait(const sProgramm: string; const sParams: string = ''; fHide: Boolean = false);
    var
      ShExecInfo: TShellExecuteInfo;
    begin
      FillChar(ShExecInfo, sizeof(ShExecInfo), 0);
      with ShExecInfo do
      begin
        cbSize := sizeof(ShExecInfo);
        fMask := SEE_MASK_NOCLOSEPROCESS;
        lpFile := PChar(sProgramm);
        lpParameters := PChar(sParams);
        lpVerb := 'open';
        if (not fHide) then
          nShow := SW_SHOW
        else
          nShow := SW_HIDE
      end;
      if (ShellExecuteEx(@ShExecInfo) and (ShExecInfo.hProcess <> 0)) then
        try
          WaitForSingleObject(ShExecInfo.hProcess, INFINITE)
        finally
          CloseHandle(ShExecInfo.hProcess);
        end;
end;

function FileOlderThanWeek(fName: String): boolean;
var
  intFileAge: LongInt;
begin
    intFileAge := FileAge(fName);
    if intFileAge = -1 then
        Result:= false
    else
        Result:= DaysBetween(Date(), FileDateToDateTime(intFileAge)) > iDaysAgo;
end;

procedure ConvertBMP2PNG(fName: String);
var
    BMP: TBitmap;
    PNG: TPNGImage;
begin
    if not (ExtractFileExt(fName)='.bmp') then exit;
    if FileExists(ChangeFileExt(fName, '.png')) then begin
        WorkList.Add(fName + ' -> Convert to PNG -> PNG exists!');
        Log(fName + ' -> Convert to PNG -> PNG exists!');
        exit;
    end;
    BMP:= TBitmap.Create;
    PNG:= TPNGImage.Create;
    try
        BMP.LoadFromFile(fName);
        if not BMP.Monochrome then begin
            WorkList.Add(fName + ' -> Color to Monochrome');
            Log(fName + ' -> Color to Monochrome');
            BMP.Monochrome:= True;
        end;
        WorkList.Add(fName + ' -> Convert to PNG');
        Log(fName + ' -> Convert to PNG');
        inc(fCount);
        PNG.Assign(BMP);
        PNG.CompressionLevel:=9;
        PNG.SaveToFile(ChangeFileExt(fName,'.png'));
    finally
        BMP.Free;
        PNG.Free;
    end;
end;

procedure DeleteBMPifPNGexists(fName: String);
begin
    if not (ExtractFileExt(fName)='.bmp') then exit;
    if FileExists(ChangeFileExt(fName, '.png')) then begin
        WorkList.Add(fName + ' -> Deleting');
        Log(fName + ' -> Deleting');
        DeleteFile(fName);
        inc(fCount);
    end;
end;

procedure CheckPNGColor(fName: String);
var
    ColType: Integer;
begin
    ColType:=GetPngColorType(fName);
    if (ColType =  COLOR_RGBALPHA) then begin
        Log(fName + ' -> ���������... 20 ���');
        ExecuteWait(ExtractFileDir(Application.ExeName) + '\truepng.exe', '/cq c=2 /md remove all /zc9 /zm9 /zs1 ' + fName, True);
        WorkList.Add(fName + ' -> ���������');
        inc(fCount);
    end;
end;

procedure ProcessFile(fName:String);
var
    FileExt: String;
begin
    FileExt:= ExtractFileExt(fName);
    if iScanMode = 2 then                                                       //������ ��������
        TryOpenFile(fName)
    else begin                                                                  //
        if iScanMode = 1 then
            if FileOlderThanWeek(fName) then begin
                Log(fName + ' -> �������');
                Exit;
            end;
        if bCheckColor and (FileExt = '.png') then CheckPNGColor(fName);
        if bCheckPalette and (FileExt = '.png') then CheckPNGPalette(fName);
        if bConvertBMP and (FileExt = '.bmp') then ConvertBMP2PNG(fName);
        if bDeleteBMP and (FileExt = '.bmp') then DeleteBMPifPNGexists(fName);
    end;                                                                        //iScanMode = 0 or 1
end;

end.
