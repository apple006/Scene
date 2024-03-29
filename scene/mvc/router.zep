
/*
 +------------------------------------------------------------------------+
 |                       ___  ___ ___ _ __   ___                          |
 |                      / __|/ __/ _ \  _ \ / _ \                         |
 |                      \__ \ (_|  __/ | | |  __/                         |
 |                      |___/\___\___|_| |_|\___|                         |
 |                                                                        |
 +------------------------------------------------------------------------+
 | Copyright (c) 2015-2016 Scene Team (http://mcorce.com)                 |
 +------------------------------------------------------------------------+
 | This source file is subject to the MIT License that is bundled         |
 | with this package in the file docs/LICENSE.txt.                        |
 |                                                                        |
 | If you did not receive a copy of the license and are unable to         |
 | obtain it through the world-wide-web, please send an email             |
 | to scene@mcorce.com so we can send you a copy immediately.             |
 +------------------------------------------------------------------------+
 | Authors: DangCheng <dangcheng@hotmail.com>                             |
 +------------------------------------------------------------------------+
 */

namespace Scene\Mvc;

use Scene\Di;
use Scene\DiInterface;
use Scene\Di\InjectionAwareInterface;
use Scene\Mvc\Router\Route;
use Scene\Mvc\Router\Exception;
use Scene\Mvc\Router\GroupInterface;
use Scene\Mvc\Router\RouteInterface;
use Scene\Events\ManagerInterface;
use Scene\Events\EventsAwareInterface;
use Scene\Http\RequestInterface;

/**
 * Scene\Mvc\Router
 *
 * Scene\Mvc\Router is the standard framework router. Routing is the
 * process of taking a URI endpoint (that part of the URI which comes after the base URL) and
 * decomposing it into parameters to determine which module, controller, and
 * action of that controller should receive the request
 *
 *<code>
 *
 *  $router = new Router();
 *
 *  $router->add(
 *      "/documentation/{chapter}/{name}\.{type:[a-z]+}",
 *      array(
 *          "controller" => "documentation",
 *          "action"     => "show"
 *      )
 *  );
 *
 *  $router->handle();
 *
 *  echo $router->getControllerName();
 *</code>
 */
class Router implements InjectionAwareInterface, RouterInterface, EventsAwareInterface
{
    /**
     * Dependency Injector
     *
     * @var null|\Scene\DiInterface
     * @access protected
    */
    protected _dependencyInjector;

    /**
     * Events Manager
     *
     * @var null|Scene\Events\ManagerInterface
     * @access protected
    */
    protected _eventsManager;

    /**
     * URI source
     *
     * @var null|int
     * @access protected
    */
    protected _uriSource;

    /**
     * Namespace
     *
     * @var null|string
     * @access protected
    */
    protected _namespace = null;

    /**
     * Module
     *
     * @var null|string
     * @access protected
    */
    protected _module = null;

    /**
     * Controller
     *
     * @var null|string
     * @access protected
    */
    protected _controller = null;

    /**
     * Action
     *
     * @var null|string
     * @access protected
    */
    protected _action = null;

    /**
     * Params
     *
     * @var null|array
     * @access protected
    */
    protected _params = [];

    /**
     * Routes
     *
     * @var null|array
     * @access protected
    */
    protected _routes;

    /**
     * Matched route
     *
     * @var null|\Scene\Mvc\Router\Route
     * @access protected
    */
    protected _matchedRoute;

    /**
     * Matches
     *
     * @var null|array
     * @access protected
    */
    protected _matches;

    /**
     * Was matched?
     *
     * @var boolean
     * @access protected
    */
    protected _wasMatched = false;

    /**
     * Default namespace
     *
     * @var null|string
     * @access protected
    */
    protected _defaultNamespace;

    /**
     * Default module
     *
     * @var null|string
     * @access protected
    */
    protected _defaultModule;

    /**
     * Default controller
     *
     * @var null|string
     * @access protected
    */
    protected _defaultController;

    /**
     * Default access
     *
     * @var null|string
     * @access protected
    */
    protected _defaultAction;

    /**
     * Default params
     *
     * @var null|array
     * @access protected
    */
    protected _defaultParams = [];

    /**
     * Remove extra slashes?
     *
     * @var null|boolean
     * @access protected
    */
    protected _removeExtraSlashes;

    /**
     * NotFound-Paths
     *
     * @var null|array
     * @access protected
    */
    protected _notFoundPaths;

    /**
     * URI source: _url
     *
     * @var int
    */
    const URI_SOURCE_GET_URL = 1;

    /**
     * URI source: REQUEST_URI
     *
     * @var int
    */
    const URI_SOURCE_SERVER_REQUEST_URI = 0;

    /**
     * POSITION_FIRST
     *
     * @var int
    */
    const POSITION_FIRST = 0;

    /**
     * POSITION_LAST
     *
     * @var int
    */
    const POSITION_LAST = 1;

    /**
     * \Scene\Mvc\Router constructor
     *
     * @param boolean|null defaultRoutes
     */
    public function __construct(boolean! defaultRoutes = true)
    {
        array routes = [];

        if defaultRoutes {

            // Two routes are added by default to match /:controller/:action and
            // /:controller/:action/:params

            let routes[] = new Route("#^/([\\w0-9\\_\\-]+)[/]{0,1}$#u", [
                "controller": 1
            ]);

            let routes[] = new Route("#^/([\\w0-9\\_\\-]+)/([\\w0-9\\.\\_]+)(/.*)*$#u", [
                "controller": 1,
                "action": 2,
                "params": 3
            ]);
        }

        let this->_routes = routes;
    }

    /**
     * Sets the dependency injector
     *
     * @param \Scene\DiInterface dependencyInjector
     */
    public function setDI(<DiInterface> dependencyInjector) -> void
    {
        let this->_dependencyInjector = dependencyInjector;
    }

    /**
     * Returns the internal dependency injector
     *
     * @return \Scene\DiInterface|null
     */
    public function getDI() -> <DiInterface>
    {
        var dependencyInjector;

        let dependencyInjector = this->_dependencyInjector;
        if typeof dependencyInjector != "object" {
            let dependencyInjector = Di::getDefault();
        }
        return dependencyInjector;
    }

    /**
     * Sets the event manager
     *
     * @param \Scene\Events\ManagerInterface eventsManager
     */
    public function setEventsManager(<ManagerInterface> eventsManager)
    {
        let this->_eventsManager = eventsManager;
    }

    /**
     * Returns the internal event manager
     *
     * @return \Scene\Events\ManagerInterface|null
     */
    public function getEventsManager() -> <ManagerInterface>
    {
        return this->_eventsManager;
    }

    /**
     * Get rewrite info. This info is read from $_GET['_url']. This returns '/' if the rewrite information cannot be read
     *
     * @return string
     */
    public function getRewriteUri() -> string
    {
        var url, urlParts, realUri;        
        
        /*
         * The developer can change the URI source
         */
        if !this->_uriSource {
            
            /**
             * Otherwise use the standard $_SERVER['REQUEST_URI']
             */
            if fetch url, _SERVER["REQUEST_URI"] {
                let urlParts = explode("?", url),
                    realUri = urlParts[0];
                if !empty realUri {
                    return realUri;
                }
            }
        } else {

            /**
             * By default we use $_GET['url'] to obtain the rewrite information
             */
            if fetch url, _GET["_url"] {
                if !empty url {
                    return url;
                }
            }
        }
        return "/";
    }

    /**
     * Sets the URI source. One of the URI_SOURCE_* constants
     *
     *<code>
     *  $router->setUriSource(Router::URI_SOURCE_SERVER_REQUEST_URI);
     *</code>
     *
     * @param int uriSource
     * @return \Scene\Mvc\RouterInterface
     */
    public function setUriSource(var uriSource) -> <RouterInterface>
    {
        let this->_uriSource = uriSource;
        return this;
    }

    /**
     * Set whether router must remove the extra slashes in the handled routes
     *
     * @param boolean remove
     * @return \Scene\Mvc\RouterInterface
     */
    public function removeExtraSlashes(boolean! remove) -> <RouterInterface>
    {
        let this->_removeExtraSlashes = remove;
        return this;
    }

    /**
     * Sets the name of the default namespace
     *
     * @param string namespaceName
     * @return \Scene\Mvc\RouterInterface
     */
    public function setDefaultNamespace(string! namespaceName) -> <RouterInterface>
    {
        let this->_defaultNamespace = namespaceName;
        return this;
    }

    /**
     * Sets the name of the default module
     *
     * @param string moduleName
     * @return \Scene\Mvc\RouterInterface
     */
    public function setDefaultModule(string! moduleName) -> <RouterInterface>
    {
        let this->_defaultModule = moduleName;
        return this;
    }

    /**
     * Sets the default controller name
     *
     * @param string controllerName
     * @return \Scene\Mvc\RouterInterface
     * @throws Exception
     */
    public function setDefaultController(string! controllerName) -> <RouterInterface>
    {
        let this->_defaultController = controllerName;
        return this;
    }

    /**
     * Sets the default action name
     *
     * @param string actionName
     * @return \Scene\Mvc\RouterInterface
     * @throws Exception
     */
    public function setDefaultAction(string! actionName) -> <RouterInterface>
    {
        let this->_defaultAction = actionName;
        return this;
    }

    /**
     * Sets an array of default paths. If a route is missing a path the router will use the defined here
     * This method must not be used to set a 404 route
     *
     *<code>
     * $router->setDefaults(array(
     *      'module' => 'common',
     *      'action' => 'index'
     * ));
     *</code>
     *
     * @param array defaults
     * @return \Scene\Mvc\RouterInterface
     * @throws Exception
     */
    public function setDefaults(array! defaults) -> <RouterInterface>
    {
        var namespaceName, module, controller, action, params;

        // Set a default namespace
        if fetch namespaceName, defaults["namespace"] {
            let this->_defaultNamespace = namespaceName;
        }

        // Set a default module
        if fetch module, defaults["module"] {
            let this->_defaultModule = module;
        }

        // Set a default controller
        if fetch controller, defaults["controller"] {
            let this->_defaultController = controller;
        }

        // Set a default action
        if fetch action, defaults["action"] {
            let this->_defaultAction = action;
        }

        // Set default parameters
        if fetch params, defaults["params"] {
            let this->_defaultParams = params;
        }

        return this;
    }

    /**
     * Returns an array of default parameters
     *
     * @return array
     */
    public function getDefaults() -> array
    {
        return [
            "namespace"  : this->_defaultNamespace,
            "module"     : this->_defaultModule,
            "controller" : this->_defaultController,
            "action"     : this->_defaultAction,
            "params"     : this->_defaultParams
        ];
    }

    /**
     * Handles routing information received from the rewrite engine
     *
     *<code>
     * //Read the info from the rewrite engine
     * $router->handle();
     *
     * //Manually passing an URL
     * $router->handle('/posts/edit/1');
     *</code>
     *
     * @param string|null uri
     * @throws Exception
     */
    public function handle(string uri = null)
    {
        var realUri, request, currentHostName, routeFound, parts,
            params, matches, notFoundPaths,
            vnamespace, module,  controller, action, paramsStr, strParams,
            route, methods, dependencyInjector,
            hostname, regexHostName, matched, pattern, handledUri, beforeMatch,
            paths, converters, part, position, matchPosition, converter, eventsManager;

        if !uri {
            /**
             * If 'uri' isn't passed as parameter it reads _GET['_url']
             */
            let realUri = this->getRewriteUri();
        } else {
            let realUri = uri;
        }

        /**
         * Remove extra slashes in the route
         */
        if this->_removeExtraSlashes && realUri != "/" {
            let handledUri = rtrim(realUri, "/");
        } else {
            let handledUri = realUri;
        }

        let request = null,
            currentHostName = null,
            routeFound = false,
            parts = [],
            params = [],
            matches = null,
            this->_wasMatched = false,
            this->_matchedRoute = null;

        let eventsManager = this->_eventsManager;

        if typeof eventsManager == "object" {
            eventsManager->fire("router:beforeCheckRoutes", this);
        }

        /**
         * Routes are traversed in reversed order
         */
        for route in reverse this->_routes {

            /**
             * Look for HTTP method constraints
             */
            let methods = route->getHttpMethods();
            if methods !== null {

                /**
                 * Retrieve the request service from the container
                 */
                if request === null {

                    let dependencyInjector = <DiInterface> this->_dependencyInjector;
                    if typeof dependencyInjector != "object" {
                        throw new Exception("A dependency injection container is required to access the 'request' service");
                    }

                    let request = <RequestInterface> dependencyInjector->getShared("request");
                }

                /**
                 * Check if the current method is allowed by the route
                 */
                if request->isMethod(methods, true) === false {
                    continue;
                }
            }

            /**
             * Look for hostname constraints
             */
            let hostname = route->getHostName();
            if hostname !== null {

                /**
                 * Retrieve the request service from the container
                 */
                if request === null {

                    let dependencyInjector = <DiInterface> this->_dependencyInjector;
                    if typeof dependencyInjector != "object" {
                        throw new Exception("A dependency injection container is required to access the 'request' service");
                    }

                    let request = <RequestInterface> dependencyInjector->getShared("request");
                }

                /**
                 * Check if the current hostname is the same as the route
                 */
                if typeof currentHostName != "object" {
                    let currentHostName = request->getHttpHost();
                }

                /**
                 * No HTTP_HOST, maybe in CLI mode?
                 */
                if typeof currentHostName == "null" {
                    continue;
                }

                /**
                 * Check if the hostname restriction is the same as the current in the route
                 */
                if memstr(hostname, "(") {
                    if !memstr(hostname, "#") {
                        let regexHostName = "#^" . hostname . "$#";
                    } else {
                        let regexHostName = hostname;
                    }
                    let matched = preg_match(regexHostName, currentHostName);
                } else {
                    let matched = currentHostName == hostname;
                }

                if !matched {
                    continue;
                }
            }

            if typeof eventsManager == "object" {
                eventsManager->fire("router:beforeCheckRoute", this, route);
            }

            /**
             * If the route has parentheses use preg_match
             */
            let pattern = route->getCompiledPattern();

            if memstr(pattern, "^") {
                let routeFound = preg_match(pattern, handledUri, matches);
            } else {
                let routeFound = pattern == handledUri;
            }

            /**
             * Check for beforeMatch conditions
             */
            if routeFound {

                if typeof eventsManager == "object" {
                    eventsManager->fire("router:matchedRoute", this, route);
                }

                let beforeMatch = route->getBeforeMatch();
                if beforeMatch !== null {

                    /**
                     * Check first if the callback is callable
                     */
                    if !is_callable(beforeMatch) {
                        throw new Exception("Before-Match callback is not callable in matched route");
                    }

                    /**
                     * Check first if the callback is callable
                     */
                    let routeFound = call_user_func_array(beforeMatch, [handledUri, route, this]);
                }

            } else {
                if typeof eventsManager == "object" {
                    let routeFound = eventsManager->fire("router:notMatchedRoute", this, route);
                }
            }

            if routeFound {

                /**
                 * Start from the default paths
                 */
                let paths = route->getPaths(), 
                    parts = paths;

                /**
                 * Check if the matches has variables
                 */
                if typeof matches == "array" {

                    /**
                     * Get the route converters if any
                     */
                    let converters = route->getConverters();

                    for part, position in paths {

                        if typeof part != "string" {
                            throw new Exception("Wrong key in paths: " . part);
                        }

                        if typeof position != "string" && typeof position != "int" {
                            continue;
                        }

                        if fetch matchPosition, matches[position] {

                            /**
                             * Check if the part has a converter
                             */
                            if typeof converters == "array" {
                                if fetch converter, converters[part] {
                                    let parts[part] = call_user_func_array(converter, [matchPosition]);
                                    continue;
                                }
                            }

                            /**
                             * Update the parts if there is no converter
                             */
                            let parts[part] = matchPosition;
                        } else {

                            /**
                             * Apply the converters anyway
                             */
                            if typeof converters == "array" {
                                if fetch converter, converters[part] {
                                    let parts[part] = call_user_func_array(converter, [position]);
                                }
                            } else {

                                /**
                                 * Remove the path if the parameter was not matched
                                 */
                                if typeof position == "int" {
                                    unset parts[part];
                                }
                            }
                        }
                    }

                    /**
                     * Update the matches generated by preg_match
                     */
                    let this->_matches = matches;
                }

                let this->_matchedRoute = route;
                break;
            }
        }

        /**
         * Update the wasMatched property indicating if the route was matched
         */
        if routeFound {
            let this->_wasMatched = true;
        } else {
            let this->_wasMatched = false;
        }

        /**
         * The route wasn't found, try to use the not-found paths
         */
        if !routeFound {
            let notFoundPaths = this->_notFoundPaths;
            if notFoundPaths !== null {
                let parts = Route::getRoutePaths(notFoundPaths),
                    routeFound = true;
            }
        }

        /**
         * Use default values before we overwrite them if the route is matched
         */
        let this->_namespace = this->_defaultNamespace,
            this->_module = this->_defaultModule,
            this->_controller = this->_defaultController,
            this->_action = this->_defaultAction,
            this->_params = this->_defaultParams;

        if routeFound {

            /**
             * Check for a namespace
             */
            if fetch vnamespace, parts["namespace"] {
                if !is_numeric(vnamespace) {
                    let this->_namespace = vnamespace;
                }
                unset parts["namespace"];
            }

            /**
             * Check for a module
             */
            if fetch module, parts["module"] {
                if !is_numeric(module) {
                    let this->_module = module;
                }
                unset parts["module"];
            }

            /**
             * Check for a controller
             */
            if fetch controller, parts["controller"] {
                if !is_numeric(controller) {
                    let this->_controller = controller;
                }
                unset parts["controller"];
            }

            /**
             * Check for an action
             */
            if fetch action, parts["action"] {
                if !is_numeric(action) {
                    let this->_action = action;
                }
                unset parts["action"];
            }

            /**
             * Check for parameters
             */
            if fetch paramsStr, parts["params"] {
                if typeof paramsStr == "string" {
                    let strParams = trim(paramsStr, "/");
                    if strParams !== "" {
                        let params = explode("/", strParams);
                    }
                }

                unset parts["params"];
            }

            if count(params) {
                let this->_params = array_merge(params, parts);
            } else {
                let this->_params = parts;
            }
        }

        if typeof eventsManager == "object" {
            eventsManager->fire("router:afterCheckRoutes", this);
        }
    }

    /**
     * Adds a route to the router without any HTTP constraint
     *
     *<code>
     * use Scene\Mvc\Router;
     *
     * $router->add('/about', 'About::index');
     * $router->add('/about', 'About::index', ['GET', 'POST']);
     * $router->add('/about', 'About::index', ['GET', 'POST'], Router::POSITION_FIRST);
     *</code>
     *
     * @param string pattern
     * @param mixed paths
     * @param string|null httpMethods
     * @return \Scene\Mvc\Router\RouteInterface
     * 
     */
    public function add(string! pattern, var paths = null, var httpMethods = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        var route;

        /**
         * Every route is internally stored as a Scene\Mvc\Router\Route
         */
        let route = new Route(pattern, paths, httpMethods);

        switch position {

            case self::POSITION_LAST:
                let this->_routes[] = route;
                break;

            case self::POSITION_FIRST:
                let this->_routes = array_merge([route], this->_routes);
                break;

            default:
                throw new Exception("Invalid route position");
        }

        return route;
    }

    /**
     * Adds a route to the router that only match if the HTTP method is GET
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addGet(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "GET", position);
    }

    /**
     * Adds a route to the router that only match if the HTTP method is POST
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addPost(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "POST", position);
    }

    /**
     * Adds a route to the router that only match if the HTTP method is PUT
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addPut(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "PUT", position);
    }

    /**
     * Adds a route to the router that only match if the HTTP method is PATCH
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addPatch(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "PATCH", position);
    }

    /**
     * Adds a route to the router that only match if the HTTP method is DELETE
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addDelete(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "DELETE", position);
    }

    /**
     * Add a route to the router that only match if the HTTP method is OPTIONS
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addOptions(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "OPTIONS", position);
    }

    /**
     * Adds a route to the router that only match if the HTTP method is HEAD
     *
     * @param string pattern
     * @param mixed paths
     * @return \Scene\Mvc\Router\RouteInterface
     */
    public function addHead(string! pattern, var paths = null, var position = Router::POSITION_LAST) -> <RouteInterface>
    {
        return this->add(pattern, paths, "HEAD", position);
    }

    /**
     * Mounts a group of routes in the router
     *
     * @param \Scene\Mvc\Router\GroupInterface group
     * @return \Scene\Mvc\RouteInterface
     * @throws Exception
     */
    public function mount(<GroupInterface> group) -> <RouterInterface>
    {
        var groupRoutes, beforeMatch, hostname, routes, route;

        let groupRoutes = group->getRoutes();
        if !count(groupRoutes) {
            throw new Exception("The group of routes does not contain any routes");
        }

        /**
         * Get the before-match condition
         */
        let beforeMatch = group->getBeforeMatch();

        if beforeMatch !== null {
            for route in groupRoutes {
                route->beforeMatch(beforeMatch);
            }
        }

        // Get the hostname restriction
        let hostname = group->getHostName();

        if hostname !== null {
            for route in groupRoutes {
                route->setHostName(hostname);
            }
        }

        let routes = this->_routes;

        if typeof routes == "array" {
            let this->_routes = array_merge(routes, groupRoutes);
        } else {
            let this->_routes = groupRoutes;
        }

        return this;
    }

    /**
     * Set a group of paths to be returned when none of the defined routes are matched
     *
     * @param array|string paths
     * @return \Scene\Mvc\RouteInterface
     * @throws Exception
     */
    public function notFound(var paths) -> <RouterInterface>
    {
        if typeof paths != "array" && typeof paths != "string" {
            throw new Exception("The not-found paths must be an array or string");
        }
        let this->_notFoundPaths = paths;
        return this;
    }

    /**
     * Removes all the pre-defined routes
     */
    public function clear() -> void
    {
        let this->_routes = [];
    }

    /**
     * Returns the processed namespace name
     */
    public function getNamespaceName() -> string
    {
        return this->_namespace;
    }

    /**
     * Returns the processed module name
     *
     * @return string|null
     */
    public function getModuleName() -> string
    {
        return this->_module;
    }

    /**
     * Returns the processed controller name
     *
     * @return string|null
     */
    public function getControllerName() -> string
    {
        return this->_controller;
    }

    /**
     * Returns the processed action name
     *
     * @return string|null
     */
    public function getActionName() -> string
    {
        return this->_action;
    }

    /**
     * Returns the processed parameters
     *
     * @return array|null
     */
    public function getParams() -> array
    {
        return this->_params;
    }

    /**
     * Returns the route that matchs the handled URI
     *
     * @return \Scene\Mvc\Router\RouteInterface|null
     */
    public function getMatchedRoute() -> <RouteInterface>
    {
        return this->_matchedRoute;
    }

    /**
     * Returns the sub expressions in the regular expression matched
     *
     * @return array|null
     */
    public function getMatches() -> array
    {
        return this->_matches;
    }

    /**
     * Checks if the router macthes any of the defined routes
     *
     * @return boolean
     */
    public function wasMatched() -> boolean
    {
        return this->_wasMatched;
    }

    /**
     * Returns all the routes defined in the router
     *
     * @return \Scene\Mvc\Router\RouteInterface[]|null
     */
    public function getRoutes() -> <RouteInterface[]>
    {
        return this->_routes;
    }

    /**
     * Returns a route object by its id
     *
     * @param mixed id
     * @return \Scene\Mvc\Router\RouteInterface|boolean
     * @throws Exception
     */
    public function getRouteById(var id) -> <RouteInterface> | boolean
    {
        var route;

        for route in this->_routes {
            if route->getRouteId() == id {
                return route;
            }
        }

        return false;
    }

    /**
     * Returns a route object by its name
     *
     * @param string name
     * @return \Scene\Mvc\Router\RouteInterface | boolean
     * @throws Exception
     */
    public function getRouteByName(string! name) -> <RouteInterface> | boolean
    {
        var route;

        for route in this->_routes {
            if route->getName() == name {
                return route;
            }
        }
        return false;
    }

    /**
     * Returns whether controller name should not be mangled
     */
    public function isExactControllerName() -> boolean
    {
        return true;
    }
}
