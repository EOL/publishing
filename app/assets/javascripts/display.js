function url_show(){
    var url_checkbox = document.getElementById('radio1');
    if(url_checkbox.checked){
      document.getElementById('display1').style.display = 'block';
      document.getElementById('display2').style.display = 'none';
    } 
  }
  
function file_show(){
    var file_checkbox = document.getElementById('radio2');
    if(file_checkbox.checked){
      document.getElementById('display2').style.display = 'block';
      document.getElementById('display1').style.display = 'none';
      document.getElementById('resource_harvest_frequency').value="once";
      document.getElementById('resource_uploaded_url').value="";
      
    } 
  }