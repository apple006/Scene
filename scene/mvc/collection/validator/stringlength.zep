
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

namespace Scene\Mvc\Collection\Validator;

use Scene\Mvc\Collection\Validator;
use Scene\Mvc\Collection\ValidatorInterface;
use Scene\Mvc\Collection\Exception;
use Scene\Mvc\EntityInterface;

/**
 * Scene\Mvc\Collection\Validator\StringLength
 *
 * Simply validates specified string length constraints
 *
 *<code>
 *use Scene\Mvc\Collection\Validator\StringLength as StringLengthValidator;
 *
 *class Subscriptors extends \Scene\Mvc\Collection
 *{
 *
 *  public function validation()
 *  {
 *      $this->validate(new StringLengthValidator(array(
 *          "field" => 'name_last',
 *          'max' => 50,
 *          'min' => 2,
 *          'messageMaximum' => 'We don\'t like really long names',
 *          'messageMinimum' => 'We want more than just their initials'
 *      )));
 *      if ($this->validationHasFailed() == true) {
 *          return false;
 *      }
 *  }
 *
 *}
 *</code>
 */
class StringLength extends Validator implements ValidatorInterface
{
    /**
     * Executes the validator
     *
     * @param \Scene\Mvc\EntityInterface record
     * @return boolean
     * @throws Exception
     */
    public function validate(<EntityInterface> record) -> boolean
    {
        var field, isSetMin, isSetMax, value, length, maximum, minimum, message;

        let field = this->getOption("field");
        if typeof field != "string" {
            throw new Exception("Field name must be a string");
        }

        /**
         * At least one of 'min' or 'max' must be set
         */
        let isSetMin = this->isSetOption("min");
        let isSetMax = this->isSetOption("max");

        if !isSetMin && !isSetMax {
            throw new Exception("A minimum or maximum must be set");
        }

        let value = record->readAttribute(field);

        if this->isSetOption("allowEmpty") && empty value {
            return true;
        }

        /**
         * Check if mbstring is available to calculate the correct length
         */
        if function_exists("mb_strlen") {
            let length = mb_strlen(value);
        } else {
            let length = strlen(value);
        }

        /**
         * Maximum length
         */
        if isSetMax {

            let maximum = this->getOption("max");
            if length > maximum {

                /**
                 * Check if the developer has defined a custom message
                 */
                let message = this->getOption("messageMaximum");
                if empty message {
                    let message = "Value of field ':field' exceeds the maximum :max characters";
                }

                this->appendMessage(strtr(message, [":field": field, ":max":  maximum]), field, "TooLong");
                return false;
            }
        }

        /**
         * Minimum length
         */
        if isSetMin {

            let minimum = this->getOption("min");
            if length < minimum {

                /**
                 * Check if the developer has defined a custom message
                 */
                let message = this->getOption("messageMinimum");
                if empty message {
                    let message = "Value of field ':field' is less than the minimum :min characters";
                }

                this->appendMessage(strtr(message, [":field": field, ":min":  minimum]), field, "TooShort");
                return false;
            }
        }

        return true;
    }
}
