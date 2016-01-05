
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

namespace Scene\Http\Response;

use Scene\Http\CookieInterface;
use Scene\Http\Cookie\Exception;
use Scene\Http\Response\CookiesInterface;
use Scene\Di\InjectionAwareInterface;
use Scene\DiInterface;

/**
 * Scene\Http\Response\Cookies
 *
 * This class is a bag to manage the cookies
 * A cookies bag is automatically registered as part of the 'response' service in the DI
 */
class Cookies implements CookiesInterface, InjectionAwareInterface
{

    /**
     * Dependency Injector
     *
     * @var null|\Scene\DiInterface
     * @access protected
    */
    protected _dependencyInjector;

    /**
     * Registered
     *
     * @var boolean
     * @access protected
    */
    protected _registered = false;

    /**
     * Use Encryption
     *
     * @var boolean
     * @access protected
    */
    protected _useEncryption = true;

    /**
     * Cookies
     *
     * @var null|array
     * @access protected
    */
    protected _cookies;

    /**
     * Sets the dependency injector
     *
     * @param \Scene\DiInterface $dependencyInjector
     * @throws Exception
     */
    public function setDI(<DiInterface> dependencyInjector)
    {
        let this->_dependencyInjector = dependencyInjector;
    }

    /**
     * Returns the internal dependency injector
     */
    public function getDI() -> <DiInterface>
    {
        return this->_dependencyInjector;
    }

    /**
     * Set if cookies in the bag must be automatically encrypted/decrypted
     *
     * @param boolean useEncryption
     * @return \Scene\Http\Response\CookiesInterface
     */
    public function useEncryption(boolean useEncryption) -> <CookiesInterface>
    {
        let this->_useEncryption = useEncryption;
        return this;
    }

    /**
     * Returns if the bag is automatically encrypting/decrypting cookies
     *
     * @return boolean
     */
    public function isUsingEncryption() -> boolean
    {
        return this->_useEncryption;
    }

    /**
     * Sets a cookie to be sent at the end of the request
     *
     * @param string name
     * @param mixed value
     * @param int|null expire
     * @param string|null path
     * @param boolean|null secure
     * @param string|null domain
     * @param boolean|null httpOnly
     * @return \Scene\Http\Response\CookiesInterface
     */
    public function set(string! name, value = null, int expire = 0, string path = "/", boolean secure = null, string! domain = null, boolean httpOnly = null) -> <CookiesInterface>
    {
        var cookie, encryption, dependencyInjector, response;

        let encryption = this->_useEncryption;

        /**
         * Check if the cookie needs to be updated or
         */
        if !fetch cookie, this->_cookies[name] {
            let cookie =
                <CookieInterface> this->_dependencyInjector->get("Scene\\Http\\Cookie",
                [name, value, expire, path, secure, domain, httpOnly]);

            /**
             * Pass the DI to created cookies
             */
            cookie->setDi(this->_dependencyInjector);

            /**
             * Enable encryption in the cookie
             */
            if encryption {
                cookie->useEncryption(encryption);
            }

            let this->_cookies[name] = cookie;

        } else {

            /**
             * Override any settings in the cookie
             */
            cookie->setValue(value);
            cookie->setExpiration(expire);
            cookie->setPath(path);
            cookie->setSecure(secure);
            cookie->setDomain(domain);
            cookie->setHttpOnly(httpOnly);
        }

        /**
         * Register the cookies bag in the response
         */
        if this->_registered === false {

            let dependencyInjector = this->_dependencyInjector;
            if typeof dependencyInjector != "object" {
                throw new Exception("A dependency injection object is required to access the 'response' service");
            }

            let response = dependencyInjector->getShared("response");

            /**
             * Pass the cookies bag to the response so it can send the headers at the of the request
             */
            response->setCookies(this);
        }

        return this;
    }

    /**
     * Gets a cookie from the bag
     *
     * @param string name
     * @return \Scene\Http\CookieInterface
     * @throws Exception
     */
    public function get(string! name) -> <CookieInterface>
    {
        var dependencyInjector, encryption, cookie;

        if fetch cookie, this->_cookies[name] {
            return cookie;
        }

        /**
         * Create the cookie if the it does not exist
         */
        let cookie = <CookieInterface> this->_dependencyInjector->get("Scene\\Http\\Cookie", [name]),
            dependencyInjector = this->_dependencyInjector;

        if typeof dependencyInjector == "object" {

            /**
             * Pass the DI to created cookies
             */
            cookie->setDi(dependencyInjector);

            let encryption = this->_useEncryption;

            /**
             * Enable encryption in the cookie
             */
            if encryption {
                cookie->useEncryption(encryption);
            }
        }

        let this->_cookies[name] = cookie;
        return cookie;
    }

    /**
     * Check if a cookie is defined in the bag or exists in the $_COOKIE superglobal
     *
     * @param string name
     * @return boolean
     */
    public function has(string! name) -> boolean
    {
        /**
         * Check the internal bag
         */
        if isset this->_cookies[name] {
            return true;
        }

        /**
         * Check the superglobal
         */
        if isset _COOKIE[name] {
            return true;
        }

        return false;
    }

    /**
     * Deletes a cookie by its name
     * This method does not removes cookies from the $_COOKIE superglobal
     *
     * @param string name
     * @return boolean
     * @throws Exception
     */
    public function delete(string! name) -> boolean
    {
        var cookie;

        /**
         * Check the internal bag
         */
        if fetch cookie, this->_cookies[name] {
            cookie->delete();
            return true;
        }

        return false;
    }

    /**
     * Sends the cookies to the client
     * Cookies aren't sent if headers are sent in the current request
     *
     * @return boolean
     */
    public function send() -> boolean
    {
        var cookie;

        if !headers_sent() {
            for cookie in this->_cookies {
                cookie->send();
            }

            return true;
        }

        return false;
    }

    /**
     * Reset set cookies
     *
     * @return \Scene\Http\Response\CookiesInterface
     */
    public function reset() -> <CookiesInterface>
    {
        let this->_cookies = [];
        return this;
    }
}
