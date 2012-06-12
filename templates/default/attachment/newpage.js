function trim(str) 
{ 
	return str.replace(/^\s+/,'').replace(/\s+$/,'');
}

function editSelected(web_root)
{
	if (window.getSelection)
	{
		txt = window.getSelection();
	}
	else if (document.getSelection)
	{
		txt = document.getSelection();
	}
	else if (document.selection)
	{
		txt = document.selection.createRange().text;
	}
	if(!txt){
	void(txt=prompt('Please enter the title of the page you wish to create',''))
	}
	if(txt){
		window.location = web_root+escape(txt)
	}
}

function hotkey( event, web_root )
{
 	event = (event) ? event : ((window.event) ? event : null);
	if (event)
	{
	if (event.ctrlKey ) 
	{
		var charCode = (event.charCode) ? event.charCode : ((event.which) ? event.which : event.keyCode);
		if (charCode == 14 ) { 
			editSelected(web_root);
		}
	}
	}
}