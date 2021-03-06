//
//  AddCityWithSuggestionController.swift
//  WeatherOpenMap
//
//  Created by Sara AbdulRaheem on 6/29/18.
//  Copyright © 2018 Sara AbdulRaheem. All rights reserved.
//

import Foundation

//view controller callbacks
protocol AddCityWithSuggestionDelegate {
    func updateUIWithCitiesList(suggestions:[CityDTO]) -> Void
    func notifyForCitiesExceededSpecifiedLimit()
    func updateUIWithWeatherList(weatherList:[CityDTO]) -> Void
    func notifyForCityAddeddSuccessfully()
    func notifyWithError(error:String)

}

//just an interface so we dont expose all them methods of the controller
protocol AddCityWithSuggestionHandler {
    
    //callbackDelegate reference
    var addCityWithSuggestionDelegate: AddCityWithSuggestionDelegate? { get set }
   
    
    func citySuggestionsByName(city:String)
    func saveCityInFavoriateList(city:CityDTO)
    func deleteCityFromFavoriateList(city: CityDTO)
    func fetchFavoriateCitiesWeather()
    func weatherForUserCurrentCityIfApplicable()

}



final class AddCityWithSuggestionController {
    
    var addCityWithSuggestionDelegate: AddCityWithSuggestionDelegate?
    var currentRequestCity: CityDTO?
    var citiesToRefreshList:[CityDTO]? = WOMLocalStorage.favoriateCitiesList()

   
    //MARK:internal helper methods
    private func fetchWeatherByCityName(cityDescription:String)
    {
        let weatherService = WeatherService(delegate: self)
        weatherService.executeService(cityDescription:cityDescription)
    }
    
 
}

//MARK:AddCityWithSuggestionHandler Handler implementation

extension AddCityWithSuggestionController:AddCityWithSuggestionHandler {
   
    func weatherForUserCurrentCityIfApplicable() {
        
        // first launch
        
        if (WOMLocalStorage.isApplicationFirstLaunch () == false)
            {
                let locationManager = WOMLocationManager.instance()
                locationManager.locationManagerDelegate = self
                locationManager.userCurrentLocation()
                WOMLocalStorage.saveApplicationFirstLaunch(isApplicationFirstLaunch: true)

            }

    }
    
    
    
    
    func saveCityInFavoriateList(city:CityDTO)
    {
        
        let userCitiesList = WOMLocalStorage.favoriateCitiesList()
        
        if (userCitiesList != nil && userCitiesList?.count == 5)
        {
            addCityWithSuggestionDelegate?.notifyForCitiesExceededSpecifiedLimit()
            
        }
        else
        {
            self.currentRequestCity = city
            self.fetchWeatherByCityName(cityDescription: city.cityDescription())
        }
        
    }
    
   
    func deleteCityFromFavoriateList(city: CityDTO) {
        var userCitiesList = WOMLocalStorage.favoriateCitiesList()
        userCitiesList = userCitiesList?.filter {
            return !$0.isEqual(city)
            
        }
        WOMLocalStorage.saveFavoriateCitiesList(citiesList: userCitiesList!)
        self.addCityWithSuggestionDelegate?.updateUIWithWeatherList(weatherList: userCitiesList!)

    }
    
    
    
    
    
    func citySuggestionsByName(city:String){
        
        guard self.addCityWithSuggestionDelegate != nil else { fatalError(NSLocalizedString("forget_to_attach_delegate_error_string", comment: "attach delegate"))}
        
        let citySuggestionsService = CitySuggestionsByNameService(delegate: self)
        citySuggestionsService.executeService(city:city)
    }
    
    func fetchFavoriateCitiesWeather() {
        
        guard self.addCityWithSuggestionDelegate != nil else { fatalError(NSLocalizedString("forget_to_attach_delegate_error_string", comment: "attach delegate"))}
        
        if let _ = citiesToRefreshList
        {
         
            if (citiesToRefreshList?.isEmpty == false)
            {
                self.currentRequestCity = citiesToRefreshList?.removeFirst()
                self.fetchWeatherByCityName(cityDescription: self.currentRequestCity!.cityDescription())
            }
            else
            {
                self.addCityWithSuggestionDelegate?.updateUIWithWeatherList(weatherList: [])
            }
        }
        else
        {
            self.addCityWithSuggestionDelegate?.updateUIWithWeatherList(weatherList: [])
        }
    }
 
}


extension AddCityWithSuggestionController:WOMLocationManagerDelegate
{
    func updateWithUserCurrentLocation(city: String, country: String) {
        self.saveCityInFavoriateList(city: CityDTO(cityDescription: "\(city),\(country)"))
    }
    
}

//MARK:Connectable delegate
extension AddCityWithSuggestionController:Connectable {
    func requestDidSuccess(responseData: Any, service: String) {
        
        switch service{
            
        case CitySuggestionsByNameService.className:
            
            if let suggestionsList = responseData as? CitySuggestionsAPIResponse {
                
                let suggestionsUIList = CityDTO.cityDTOArrayFromSuggestionBackendList(citySuggestionsAPIResponse: suggestionsList)
                if let userCitiesList = WOMLocalStorage.favoriateCitiesList()
                {
                    let modifiedSuggestionsUIList = suggestionsUIList.filter {
                        return !userCitiesList.contains($0)
                    }
                    addCityWithSuggestionDelegate?.updateUIWithCitiesList(suggestions: modifiedSuggestionsUIList)

                }
                else
                {
                    addCityWithSuggestionDelegate?.updateUIWithCitiesList(suggestions: suggestionsUIList)
                }
            }
        case WeatherService.className:
            
            if let weatherObject = responseData as? WeatherApiResponse {
                self.currentRequestCity?.addWeatherData(weatherApiResponse: weatherObject)
                
            }
            var userCitiesList = WOMLocalStorage.favoriateCitiesList()
            
            if userCitiesList == nil
            {
                userCitiesList = []
            }
            // this is for refresh request
            if userCitiesList?.contains(self.currentRequestCity!) ?? false
            {
                let  currentRequestIndex = userCitiesList?.index(of: self.currentRequestCity!)
                userCitiesList?.remove(at:currentRequestIndex!)
            }
            userCitiesList?.append(self.currentRequestCity!)
            WOMLocalStorage.saveFavoriateCitiesList(citiesList: userCitiesList!)
            addCityWithSuggestionDelegate?.updateUIWithWeatherList(weatherList: userCitiesList!)
          
            // this is to get the reset of cities to be refreshed
            if(self.citiesToRefreshList?.isEmpty == false)
            {
                self.currentRequestCity = citiesToRefreshList?.removeFirst()
                self.fetchWeatherByCityName(cityDescription: self.currentRequestCity!.cityDescription())
            }
            else
            {
                self.addCityWithSuggestionDelegate?.notifyForCityAddeddSuccessfully()
            }
        default:
            fatalError("Not yet implemented")
            break
        }
        
        
    }
    
    func requestDidFail(error: WAError, errorResponse: Any, service: String) {
          switch service{
          case WeatherService.className:
            let userList = WOMLocalStorage.favoriateCitiesList()
                if userList != nil && userList?.isEmpty == false
                {
                   self.addCityWithSuggestionDelegate?.updateUIWithWeatherList(weatherList: userList!)
                }
            else
                {
                    self.addCityWithSuggestionDelegate?.notifyWithError(error: error.message)
                }
          default:
            self.addCityWithSuggestionDelegate?.notifyWithError(error: error.message)
            break
        }
    }
    
    
    
}

