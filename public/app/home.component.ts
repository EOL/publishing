import {Component, OnInit} from 'angular2/core' 
import {RouteParams} from 'angular2/router' 
import {Http, HTTP_PROVIDERS} from 'angular2/http';
@Component({
 selector: 'home', templateUrl: '/app/home.component.html'
  }) 
  export class HomeComponent {
   message: string; 
   constructor( public http: Http){
    this.http.get('http://localhost:3000/api') 
    .subscribe( 
    data => this.message = data.json().some,
     err => console.log(err) 
     ); 
   } 
 }

