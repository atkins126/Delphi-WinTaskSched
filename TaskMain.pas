﻿(* Program to demonstrate the use of the
   Delphi interface to Windows Task Scheduler 2.0

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   Vers. 1.0 - Oct. 2017
   last mofified: April 2019
   *)

unit TaskMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Buttons,
  Vcl.ExtCtrls, WinTask;

type
  TMainForm = class(TForm)
    gbDetails: TGroupBox;
    Label1: TLabel;
    edUserAccount: TLabeledEdit;
    edComment: TLabeledEdit;
    edCreator: TLabeledEdit;
    edStatus: TLabeledEdit;
    edApplication: TLabeledEdit;
    edParameters: TLabeledEdit;
    edWorkDir: TLabeledEdit;
    lbTriggers: TListBox;
    btnDelete: TBitBtn;
    btbNew: TBitBtn;
    btbClose: TBitBtn;
    lvTasks: TListView;
    edCompat: TLabeledEdit;
    edLogonType: TLabeledEdit;
    btbEdit: TBitBtn;
    btbRun: TBitBtn;
    Timer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btbCloseClick(Sender: TObject);
    procedure lvTasksSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure FormResize(Sender: TObject);
    procedure btbNewClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btbEditClick(Sender: TObject);
    procedure btbRunClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
  private
    { Private-Deklarationen }
    WinTasks : TWinTaskScheduler;
    SelectedTaskIndex : integer;
    function GetListIndex (ATaskIndex : integer) : integer;
    procedure UpdateListView (AIndex : integer);
    procedure ShowData(Item: TListItem; Selected: Boolean);
  public
    { Public-Deklarationen }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses System.Win.ComObj, System.DateUtils, Vcl.FileCtrl, Winapi.ActiveX,
  TaskSchedDlg;

procedure TMainForm.FormCreate(Sender: TObject);
var
  hr : HResult;
begin
//  CoInitializeEx(nil,COINIT_MULTITHREADED);
  hr:=CreateWinTaskScheduler(WinTasks);
  if failed(hr) then begin
    if hr=NotAvailOnXp then begin
      MessageDlg('Windows Task Scheduler 2.0 requires at least Windows Vista',mtError,[mbOK],0);
      Halt(1)
      end
    else begin
      MessageDlg('Error initializing TWinTaskScheduler: '+IntToHex(hr,8),mtError,[mbOK],0);
      Halt(2)
      end;
    end;
  end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  WinTasks.Free;
//  CoUninitialize;
  end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  with lvTasks do begin
    Columns[1].Width:=80;
    Columns[2].Width:=150;
    Columns[3].Width:=150;
    Columns[0].Width:=Width-401;
    end;
  end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  UpdateListView(0);
  end;

procedure TMainForm.UpdateListView (AIndex : integer);
var
  i : integer;
begin
  lvTasks.Clear;
  lvTasks.Items.BeginUpdate;
  with WinTasks.TaskFolder do begin
    for i:=0 to TaskCount-1 do with Tasks[i] do begin
      with lvTasks.Items.Add do begin
        Caption:=TaskName;
        Data:=pointer(i);
        SubItems.Add(StatusAsString);
        SubItems.Add(LastRunTimeAsString);
        SubItems.Add(NextRunTimeAsString);
        end;
      end;
    end;
  lvTasks.Items.EndUpdate;
  with lvTasks do if AIndex>=0 then begin
    if AINdex>=Items.Count then AIndex:=Items.Count-1;
    ItemIndex:=AIndex;
    Invalidate;
    Selected.MakeVisible(false);
    end;
  end;

procedure TMainForm.lvTasksSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  ShowData(Item,Selected);
  end;

procedure TMainForm.ShowData(Item: TListItem; Selected: Boolean);
var
  i  : integer;
const
  LogonTypes : array[TLogonType] of string =
    ('Not specified','User and password','Interactive token','As logged on user',
     'As group member','Local system or service','Interactive or passord');

  procedure ShowPath (AEdit : TCustomEdit; const APath : string);
  begin
    with AEdit do begin
      Text:=MinimizeName(APath,self.Canvas,Width);
      ShowHint:=length(APath)>length(Text);
      if ShowHint then Hint:=APath;
      end;
    end;

  procedure ShowText (AEdit : TCustomEdit; const AText : string);
  begin
    with AEdit do begin
      Text:=AText;
      ShowHint:=Canvas.TextWidth(AText)>Width;
      if ShowHint then Hint:=WrapText(AText,80);
      end;
    end;

begin
  if Assigned(Item) and Selected then begin
    with WinTasks.TaskFolder.Tasks[integer(Item.Data)],Definition do begin
      gbDetails.Caption:='Properties of task: '+TaskName;
      ShowText(edStatus,StatusAsString);
      ShowText(edLogonType,LogonTypes[LogonType]);
      if LogonType=ltGroup then ShowText(edUserAccount,GroupId)
      else ShowText(edUserAccount,UserId);
      ShowText(edComment,Description);
      ShowText(edCreator,Author);
      ShowText(edStatus,DateAsString);
      ShowText(edCompat,CompatibilityAsString);
//      cbReRun.Checked:=RunIfMissed;
      if ActionCount>0 then with Actions[0] do if ActionType=taExec then
          with TWinTaskExecAction(Actions[0]) do begin
        ShowPath(edApplication,ApplicationPath);
        ShowText(edParameters,Arguments);
        ShowPath(edWorkDir,WorkingDirectory);
        end
      else begin
        edApplication.Text:='';
        edParameters.Text:='';
        edWorkDir.Text:='';
        end;
      lbTriggers.Clear;
      for i:=0 to TriggerCount-1 do with Triggers[i] do begin
        lbTriggers.Items.Add(TriggerString);
        end;
      SelectedTaskIndex:=TaskIndex;
      end;
    end
  end;

procedure TMainForm.TimerTimer(Sender: TObject);
begin
  UpdateListView(lvTasks.ItemIndex);
//  ShowData(lvTasks.Items[lvTasks.ItemIndex],true);
  end;

function TMainForm.GetListIndex (ATaskIndex : integer) : integer;
var
  i  : integer;
begin
  Result:=-1;
  with lvTasks.Items do for i:=0 to Count-1 do if integer(Item[i].Data)=ATaskIndex then begin
    Result:=i; Break;
    end;
  end;

procedure TMainForm.btbCloseClick(Sender: TObject);
begin
  Close;
  end;

procedure TMainForm.btbNewClick(Sender: TObject);
var
  td : TWinTask;
  n  : integer;
  sn,user,pwd : string;
  ok : boolean;
begin
  User:=''; pwd:=''; sn:='';
  if InputQuery('Create new Task?','Name of task:',sn) then with WinTasks do begin
    n:=TaskFolder.IndexOf(sn);
    if n<0 then begin
      td:=NewTask;
      with td do begin
        Description:='Test for new task';
        LogOnType:=ltToken;   // as current user
        Date:=Now;
        end;
      ok:=TaskScheduleDialog.Execute(sn,td,user,pwd);
      end
    else begin
      ok:=MessageDlg('Task already exists - edit?',mtConfirmation,mbYesNo,0)=mrYes;
      ok:=ok and TaskScheduleDialog.Execute(sn,TaskFolder.Tasks[n].Definition,user,pwd);
      end;
    if ok then with TaskFolder do begin
      n:=RegisterTask(sn,td,User,pwd);
      if n<0 then MessageDlg('Could not create scheduled task!'+sLineBreak
        +SysErrorMessage(ResultCode(ErrorCode))+' - '+ErrorMessage,
        mtError,[mbOK],0)
      else begin
        n:=GetListIndex(n);
        UpdateListView(n);
        ShowData(lvTasks.Items[n],true);
        end;
      end;
    end;
  end;

procedure TMainForm.btbRunClick(Sender: TObject);
begin
  if (SelectedTaskIndex>=0) then with WinTasks.TaskFolder.Tasks[SelectedTaskIndex] do begin
    if Status=tsReady then begin
      if MessageDlg('Run selected task?',mtConfirmation,mbYesNo,0)=mrYes then Run;
      end
    else if Status=tsRunning then begin
      if MessageDlg('Stop selected task?',mtConfirmation,mbYesNo,0)=mrYes then Stop;
      end;
    UpdateListView(GetListIndex(SelectedTaskIndex));
    end;
  end;

procedure TMainForm.btbEditClick(Sender: TObject);
var
  user,pwd : string;
  n        : integer;
begin
  if SelectedTaskIndex>=0 then with WinTasks.TaskFolder,Tasks[SelectedTaskIndex] do begin
    if TaskScheduleDialog.Execute(TaskName,Definition,user,pwd) then begin
      n:=RegisterTask(TaskName,Definition,user,pwd);
      if n<0 then begin   // Error
        MessageDlg('Could not modify scheduled task!'+sLineBreak
                   +SysErrorMessage(ResultCode(ErrorCode))+' - '+ErrorMessage,
                   mtError,[mbOK],0);
        Refresh;
        end
      else begin
        n:=GetListIndex(n);
        UpdateListView(n);
        ShowData(lvTasks.Items[n],true);
        end;
      end;
    end;
  end;

procedure TMainForm.btnDeleteClick(Sender: TObject);
var
  sn : string;
begin
  if SelectedTaskIndex>=0 then with WinTasks.TaskFolder do begin
    sn:=Tasks[SelectedTaskIndex].TaskName;
    if MessageDlg(Format('Delete task "%s"?',[sn]),mtConfirmation,mbYesNo,0)=mrYes then begin
      if failed(DeleteTask(sn)) then MessageDlg(ErrorMessage,mtError,[mbOK],0)
      else UpdateListView(GetListIndex(SelectedTaskIndex));
      end;
    end;
  end;

end.
