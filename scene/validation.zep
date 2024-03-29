
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

namespace Scene;

use Scene\Di\Injectable;
use Scene\ValidationInterface;
use Scene\Validation\Exception;
use Scene\Validation\Message\Group;
use Scene\Validation\MessageInterface;
use Scene\Validation\ValidatorInterface;

/**
 * Scene\Validation
 *
 * Allows to validate data using custom or built-in validators
 */
class Validation extends Injectable implements ValidationInterface
{
    
    /**
     * Data
     *
     * @var null|array|object
     * @access protected
    */
    protected _data;

    /**
     * Entity
     *
     * @var null|object
     * @access protected
    */
    protected _entity;

    /**
     * Validators
     *
     * @var null|array
     * @access protected
    */
    protected _validators { set };

    /**
     * Filters
     *
     * @var null|array
     * @access protected
    */
    protected _filters;

    /**
     * Messages
     *
     * @var null|\Scene\Validation\Message\Group
     * @access protected
    */
    protected _messages;

    /**
     * Default message
     *
     * @var null|array
     * @access protected
    */
    protected _defaultMessages;

    /**
     * Labels
     *
     * @var null|array
     * @access protected
    */
    protected _labels;

    /**
     * Values
     *
     * @var null
     * @access protected
    */
    protected _values;

    /**
     * \Scene\Validation constructor
     *
     * @param array|null validators
     */
    public function __construct(array validators = null)
    {
        if typeof validators == "array" {
            let this->_validators = validators;
        }

        this->setDefaultMessages();

        /**
         * Check for an 'initialize' method
         */
        if method_exists(this, "initialize") {
            this->{"initialize"}();
        }
    }

    /**
     * Validate a set of data according to a set of rules
     *
     * @param array|object|null data
     * @param object|null entity
     * @return \Scene\Validation\Message\Group
     */
    public function validate(var data = null, var entity = null) -> <Group>
    {
        var validators, messages, scope, field, validator, status;

        let validators = this->_validators;
        if typeof validators != "array" {
            throw new Exception("There are no validators to validate");
        }

        /**
         * Clear pre-calculated values
         */
        let this->_values = null;

        /**
         * Implicitly creates a Scene\Validation\Message\Group object
         */
        let messages = new Group();

        if entity !== null {
            this->setEntity(entity);
        }

        /**
         * Validation classes can implement the 'beforeValidation' callback
         */
        if method_exists(this, "beforeValidation") {
            let status = this->{"beforeValidation"}(data, entity, messages);
            if status === false {
                return status;
            }
        }

        let this->_messages = messages;

        if typeof data == "array" || typeof data == "object" {
            let this->_data = data;
        }

        for scope in validators {

            if typeof scope != "array" {
                throw new Exception("The validator scope is not valid");
            }

            let field = scope[0],
                validator = scope[1];

            if typeof validator != "object" {
                throw new Exception("One of the validators is not valid");
            }

            /**
             * Call internal validations, if it returns true, then skip the current validator
             */
            if this->preChecking(field, validator) {
                continue;
            }

            /**
             * Check if the validation must be canceled if this validator fails
             */
            if validator->validate(this, field) === false {
                if validator->getOption("cancelOnFail") {
                    break;
                }
            }
        }

        /**
         * Get the messages generated by the validators
         */
        let messages = this->_messages;
        if method_exists(this, "afterValidation") {
            this->{"afterValidation"}(data, entity, messages);
        }

        return messages;
    }

    /**
     * Adds a validator to a field
     *
     * @param string field
     * @param \Scene\Validation\ValidatorInterface
     * @return \Scene\ValidationInterface
     */
    public function add(string field, <ValidatorInterface> validator) -> <ValidationInterface>
    {
        let this->_validators[] = [field, validator];
        return this;
    }

    /**
     * Alias of `add` method
     *
     * @param string field
     * @param \Scene\Validation\ValidatorInterface
     * @return \Scene\ValidationInterface
     */
    public function rule(string field, <ValidatorInterface> validator) -> <ValidationInterface>
    {
        return this->add(field, validator);
    }

    /**
     * Adds the validators to a field
     *
     * @param string field
     * @param array validators
     * @return \Scene\ValidationInterface
     */
    public function rules(string! field, array! validators) -> <ValidationInterface>
    {
        var validator;

        for validator in validators {
            if validator instanceof ValidatorInterface {
                let this->_validators[] = [field, validator];
            }
        }
        return this;
    }

    /**
     * Adds filters to the field
     *
     * @param string field
     * @param array|string filters
     * @return \Scene\ValidationInterface
     */
    public function setFilters(string field, filters) -> <ValidationInterface>
    {
        let this->_filters[field] = filters;
        return this;
    }

    /**
     * Returns all the filters or a specific one
     *
     * @param string|null field
     * @return mixed
     */
    public function getFilters(string field = null)
    {
        var filters, fieldFilters;
        let filters = this->_filters;

        if typeof field == "null" {
            return filters;
        }

        if !fetch fieldFilters, filters[field] {
            return null;
        }

        return fieldFilters;
    }

    /**
     * Returns the validators added to the validation
     *
     * @return array
     */
    public function getValidators() -> array
    {
        return this->_validators;
    }

    /**
     * Sets the bound entity
     *
     * @param object entity
     */
    public function setEntity(entity)
    {
        if typeof entity != "object" {
            throw new Exception("Entity must be an object");
        }
        let this->_entity = entity;
    }

    /**
     * Returns the bound entity
     *
     * @return object
     */
    public function getEntity()
    {
        return this->_entity;
    }

    /**
     * Adds default messages to validators
     *
     * @param array messages
     * @return array
     */
    public function setDefaultMessages(array messages = []) -> array
    {
        var defaultMessages;

        let defaultMessages = [
            "Alnum": "Field :field must contain only letters and numbers",
            "Alpha": "Field :field must contain only letters",
            "Between": "Field :field must be within the range of :min to :max",
            "Confirmation": "Field :field must be the same as :with",
            "Digit": "Field :field must be numeric",
            "Email": "Field :field must be an email address",
            "ExclusionIn": "Field :field must not be a part of list: :domain",
            "FileEmpty": "Field :field must not be empty",
            "FileIniSize": "File :field exceeds the maximum file size",
            "FileMaxResolution": "File :field must not exceed :max resolution",
            "FileMinResolution": "File :field must be at least :min resolution",
            "FileSize": "File :field exceeds the size of :max",
            "FileType": "File :field must be of type: :types",
            "FileValid": "Field :field is not valid",
            "Identical": "Field :field does not have the expected value",
            "InclusionIn": "Field :field must be a part of list: :domain",
            "Numericality": "Field :field does not have a valid numeric format",
            "PresenceOf": "Field :field is required",
            "Regex": "Field :field does not match the required format",
            "TooLong": "Field :field must not exceed :max characters long",
            "TooShort": "Field :field must be at least :min characters long",
            "Uniqueness": "Field :field must be unique",
            "Url": "Field :field must be a url",
            "CreditCard": "Field :field is not valid for a credit card number",
            "Date": "Field :field is not a valid date"
        ];

        let this->_defaultMessages = array_merge(defaultMessages, messages);
        return this->_defaultMessages;
    }

    /**
     * Get default message for validator type
     *
     * @param string type
     * @return string
     */
    public function getDefaultMessage(string! type) -> string
    {
        if !isset this->_defaultMessages[type] {
            return "";
        }
        return this->_defaultMessages[type];
    }

    /**
     * Returns the registered validators
     *
     * @return \Scene\Validation\Message\Group
     */
    public function getMessages() -> <Group>
    {
        return this->_messages;
    }

    /**
     * Adds labels for fields
     *
     * @param array labels
     */
    public function setLabels(array! labels)
    {
        let this->_labels = labels;
    }

    /**
     * Get label for field
     *
     * @param string field
     * @return string
     */
    public function getLabel(string! field)
    {
        var labels, value;
        let labels = this->_labels;
        if typeof labels == "array" {
            if fetch value, labels[field] {
                return value;
            }
        }
        return field;
    }

    /**
     * Appends a message to the messages list
     *
     * @param \Scene\Validation\MessageInterface message
     * @return \Scene\ValidationInterface
     */
    public function appendMessage(<MessageInterface> message) -> <ValidationInterface>
    {
        this->_messages->appendMessage(message);
        return this;
    }

    /**
     * Assigns the data to an entity
     * The entity is used to obtain the validation values
     *
     * @param object entity
     * @param array|object data
     * @return \Scene\ValidationInterface
     */
    public function bind(entity, data) -> <ValidationInterface>
    {
        if typeof entity != "object" {
            throw new Exception("Entity must be an object");
        }

        if typeof data != "array" && typeof data != "object" {
            throw new Exception("Data to validate must be an array or object");
        }

        let this->_entity = entity,
            this->_data = data;

        return this;
    }

    /**
     * Gets the a value to validate in the array/object data source
     *
     * @param string field
     * @return mixed
     */
    public function getValue(string field)
    {
        var entity, method, value, data, values,
            filters, fieldFilters, dependencyInjector,
            filterService;

        let entity = this->_entity;

        /**
         * If the entity is an object use it to retrieve the values
         */
        if typeof entity == "object" {
            let method = "get" . camelize(field);
            if method_exists(entity, method) {
                let value = entity->{method}();
            } else {
                if method_exists(entity, "readAttribute") {
                    let value = entity->readAttribute(field);
                } else {
                    if isset entity->{field} {
                        let value = entity->{field};
                    } else {
                        let value = null;
                    }
                }
            }
            return value;
        }

        let data = this->_data;

        if typeof data != "array" && typeof data != "object" {
            throw new Exception("There is no data to validate");
        }

        /**
         * Check if there is a calculated value
         */
        let values = this->_values;
        if fetch value, values[field] {
            return value;
        }

        let value = null;
        if typeof data == "array" {
            if isset data[field] {
                let value = data[field];
            }
        } elseif typeof data == "object" {
            if isset data->{field} {
                let value = data->{field};
            }
        }

        if typeof value == "null" {
            return null;
        }

        let filters = this->_filters;
        if typeof filters == "array" {

            if fetch fieldFilters, filters[field] {

                if fieldFilters {

                    let dependencyInjector = this->getDI();
                    if typeof dependencyInjector != "object" {
                        let dependencyInjector = Di::getDefault();
                        if typeof dependencyInjector != "object" {
                            throw new Exception("A dependency injector is required to obtain the 'filter' service");
                        }
                    }

                    let filterService = dependencyInjector->getShared("filter");
                    if typeof filterService != "object" {
                        throw new Exception("Returned 'filter' service is invalid");
                    }

                    return filterService->sanitize(value, fieldFilters);
                }
            }
        }

        /**
         * Cache the calculated value
         */
        let this->_values[field] = value;

        return value;
    }

    /**
     * Internal validations, if it returns true, then skip the current validator
     *
     * @param string field
     * @param \Scene\Validation\ValidatorInterface validator
     * @return boolean
     */
    protected function preChecking(string field, <ValidatorInterface> validator) -> boolean
    {
        if validator->getOption("allowEmpty", false) {
            if method_exists(validator, "isAllowEmpty") {
                return validator->isAllowEmpty(this, field);
            } else {
                return empty this->getValue(field);
            }
        }

        return false;
    }
}
