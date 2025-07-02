// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

using System;
using System.Text;
using ReEngine;
using System.IO;

class FileWatcher : IScript
{
	FileSystemWatcher fws = null;

	public void Init()
	{

	}

	public void Destroy()
	{
		if (fws != null)
		{
			fws.Dispose();
			fws = null;
		}
	}

	public void Command(string args, StringBuilder output)
	{
		switch (args)
		{
			case "start":
				if (ScriptContext.GetArgsCount() < 2)
				{
					output.Append("error");
					break;
				}
				
				if (fws != null)
				{
					output.Append("error");
					break;
				}

				try
				{
					string pathWatching = ScriptContext.GetArg(0);
					string filter = ScriptContext.GetArg(1);
					
					if (!Directory.Exists(pathWatching))
					{
						output.Append("path_not_found");
						break;
					}

					fws = new FileSystemWatcher();
					fws.Path = pathWatching;
					fws.Filter = filter;
					fws.NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.DirectoryName;
					fws.IncludeSubdirectories = true;

					fws.Changed += OnChanged;
					fws.Created += OnChanged;
					fws.Deleted += OnChanged;
					fws.Renamed += OnRenamed;
					fws.Error += OnError;

					fws.EnableRaisingEvents = true;

					string pathAbs = Path.GetFullPath(pathWatching);
					
					output.Append("ok");
				}
				catch (Exception ex)
				{
					output.Append("error");
				}
				break;
			case "stop":
				if (fws != null)
				{
					fws.Dispose();
					fws = null;
					output.Append("ok");
				}
				else
				{
					output.Append("error");
				}
				break;
		}
	}

	private void OnChanged(object source, FileSystemEventArgs e)
	{
		ScriptContext.AddCallback("file_watcher_callback", new[] { $"file_changed;{e.FullPath};{e.ChangeType}" });
	}

	private void OnRenamed(object source, RenamedEventArgs e)
	{
		ScriptContext.AddCallback("file_watcher_callback", new[] { $"file_renamed;{e.OldFullPath};{e.FullPath}" });
	}

	private void OnError(object source, ErrorEventArgs e)
	{
		ScriptContext.AddCallback("file_watcher_callback", new[] { $"error;{e.GetException().Message}" });
	}
}

