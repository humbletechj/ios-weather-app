import Foundation
import Alamofire

enum WeatherError: Error, LocalizedError {
    
    case unknown
    case invalidCity
    case custom(description: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCity:
            return "This is an invalid city. Please try again."
        case .unknown:
            return "Hey, this is an unknown error!"
        case .custom(let description):
            return description
        }
    }
    
}

struct WeatherManager {
    
    // Ключи для API нельзя вот так просто хардкодить из соображений безопасности. Так как это пример, он оставлен здесь для наглядности.
    // При выполнении ЛР нужно будет вынести ключ от апишки в переменную окружения или в отдельный файл.
    private let API_KEY = "c47764b2cba99dceee66c06850c5b778"
    private let cacheManager = CacheManager()
    
    func fetchWeather(lat: Double, lon: Double, completion: @escaping (Result<WeatherModel, Error>) -> Void) {
        let path = "https://api.openweathermap.org/data/2.5/weather?appid=%@&units=metric&lat=%f&lon=%f"
        let urlString = String(format: path, API_KEY, lat, lon)
        handleRequest(urlString: urlString, completion: completion)
    }
    
    func fetchWeather(byCity city: String, completion: @escaping (Result<WeatherModel, Error>) -> Void) {
        let query = city.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? city
        let path = "https://api.openweathermap.org/data/2.5/weather?q=%@&appid=%@&units=metric"
        let urlString = String(format: path, query, API_KEY)
        handleRequest(urlString: urlString, completion: completion)
    }
    
    private func handleRequest(urlString: String, completion: @escaping (Result<WeatherModel, Error>) -> Void) {
        
        AF.request(urlString)
            .validate()
            .responseDecodable(of: WeatherData.self, queue: .main, decoder: JSONDecoder()) { (response) in
            switch response.result {
            case .success(let weatherData):
                let model = weatherData.model
                self.cacheManager.cacheCity(cityName: model.countryName)
                completion(.success(model))
            case .failure(let error):
                if let err = self.getWeatherError(error: error, data: response.data) {
                    completion(.failure(err))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func getWeatherError(error: AFError, data: Data?) -> Error? {
        if error.responseCode == 404,
            let data = data,
            let failure = try? JSONDecoder().decode(WeatherDataFailure.self, from: data) {
            let message = failure.message
            return WeatherError.custom(description: message)
        } else {
            return nil
        }
    }
    
}
